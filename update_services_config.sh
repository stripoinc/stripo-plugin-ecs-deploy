#!/bin/bash

# New version of script for automatic service configuration update from JSON files
# Usage: ./update_services_config.sh [aws_profile]

set -e

# Determine project root directory (works from any subdirectory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to get image and tag from JSON file
get_image_info() {
    local image_name="$1"
    local json_file="$PROJECT_ROOT/services/IMAGES_PLUGIN_VERSION.json"
    
    if [ ! -f "$json_file" ]; then
        log_warning "File $json_file not found, using tag from service JSON configuration" >&2
        return 1
    fi
    
    # Get tag for image
    local image_tag=$(jq -r ".[\"$image_name\"]" "$json_file" 2>/dev/null)
    
    if [ "$image_tag" = "null" ] || [ -z "$image_tag" ]; then
        log_warning "Tag for image $image_name not found in $json_file" >&2
        return 1
    fi
    
    echo "$image_tag"
}

# Function to replace placeholders in JSON
replace_placeholders() {
    local json_content="$1"
    local env_prefix="$2"
    local aws_region="$3"
    local postgresql_ip="$4"
    local redis_ip="$5"
    local domain_name="$6"
    local s3_access_key="$7"
    local s3_secret_key="$8"
    local s3_bucket_name="$9"
    local s3_bucket_region="${10}"
    local s3_base_download_url="${11}"
    
    # Replace infrastructure placeholders (use | as separator to avoid conflicts with /)
    json_content=$(echo "$json_content" | sed "s|{{ENV_PREFIX}}|$env_prefix|g")
    json_content=$(echo "$json_content" | sed "s|{{AWS_REGION}}|$aws_region|g")
    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PRIVATE_IP}}|$postgresql_ip|g")
    json_content=$(echo "$json_content" | sed "s|{{REDIS_PRIVATE_IP}}|$redis_ip|g")
    json_content=$(echo "$json_content" | sed "s|{{DOMAIN_NAME}}|$domain_name|g")
    json_content=$(echo "$json_content" | sed "s|{{S3_ACCESS_KEY_ID}}|$s3_access_key|g")
    json_content=$(echo "$json_content" | sed "s|{{S3_SECRET_ACCESS_KEY}}|$s3_secret_key|g")
    json_content=$(echo "$json_content" | sed "s|{{S3_BUCKET_NAME}}|$s3_bucket_name|g")
    json_content=$(echo "$json_content" | sed "s|{{S3_BUCKET_REGION}}|$s3_bucket_region|g")
    json_content=$(echo "$json_content" | sed "s|{{S3_BASE_DOWNLOAD_URL}}|$s3_base_download_url|g")
    
    # Replace password placeholders (if passwords are loaded)
    if [ -n "$POSTGRESQL_PASSWORDS" ] && [ -n "$REDIS_PASSWORD" ] && [ -n "$TIMER_PASSWORD" ]; then
        # PostgreSQL database passwords
        for db_name in $(echo "$POSTGRESQL_PASSWORDS" | yq eval 'keys | .[]' 2>/dev/null); do
            local password=$(echo "$POSTGRESQL_PASSWORDS" | yq eval ".$db_name" 2>/dev/null)
            case "$db_name" in
                "ai_service")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_AI_SERVICE}}|$password|g")
                    ;;
                "countdowntimer")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_COUNTDOWNTIMER}}|$password|g")
                    ;;
                "stripo_plugin_local_documents")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_DOCUMENTS}}|$password|g")
                    ;;
                "stripo_plugin_local_bank_images")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_BANK_IMAGES}}|$password|g")
                    ;;
                "stripo_plugin_local_plugin_details")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_PLUGIN_DETAILS}}|$password|g")
                    ;;
                "stripo_plugin_local_plugin_stats")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_PLUGIN_STATS}}|$password|g")
                    ;;
                "stripo_plugin_local_securitydb")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_SECURITYDB}}|$password|g")
                    ;;
                "stripo_plugin_local_html_gen")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_HTML_GEN}}|$password|g")
                    ;;
                "stripo_plugin_local_custom_blocks")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_CUSTOM_BLOCKS}}|$password|g")
                    ;;
                "stripo_plugin_local_drafts")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_DRAFTS}}|$password|g")
                    ;;
                "stripo_plugin_local_timers")
                    json_content=$(echo "$json_content" | sed "s|{{POSTGRESQL_PASSWORD_TIMERS}}|$password|g")
                    ;;
            esac
        done
        
        # Other credentials
        json_content=$(echo "$json_content" | sed "s|{{REDIS_PASSWORD}}|$REDIS_PASSWORD|g")
        json_content=$(echo "$json_content" | sed "s|{{TIMER_PASSWORD}}|$TIMER_PASSWORD|g")
        json_content=$(echo "$json_content" | sed "s|{{TIMER_USERNAME}}|$TIMER_USERNAME|g")
        
        # Generate secrets if they don't exist
        if [ -z "$JWT_SECRET" ]; then
            JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
        fi
        if [ -z "$COUNTDOWN_SECRET_KEY" ]; then
            COUNTDOWN_SECRET_KEY=$(openssl rand -base64 32 | tr -d '\n')
        fi
        
        json_content=$(echo "$json_content" | sed "s|{{JWT_SECRET}}|$JWT_SECRET|g")
        json_content=$(echo "$json_content" | sed "s|{{COUNTDOWN_SECRET_KEY}}|$COUNTDOWN_SECRET_KEY|g")
    fi
    
    echo "$json_content"
}

# Function to read passwords from passwords.yml
read_passwords_from_yml() {
    local passwords_file="$PROJECT_ROOT/02-servers-bootstrap/group_vars/passwords.yml"
    
    if [ ! -f "$passwords_file" ]; then
        log_error "Passwords file not found: $passwords_file"
        return 1
    fi
    
    # Read PostgreSQL passwords
    local postgresql_passwords=$(yq eval '.postgresql_passwords' "$passwords_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Failed to read PostgreSQL passwords from $passwords_file"
        return 1
    fi
    
    # Read Redis password
    local redis_password=$(yq eval '.redis_password' "$passwords_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Failed to read Redis password from $passwords_file"
        return 1
    fi
    
    # Read countdown timer credentials
    local timer_username=$(yq eval '.countdown_timer.username' "$passwords_file" 2>/dev/null)
    local timer_password=$(yq eval '.countdown_timer.password' "$passwords_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Failed to read countdown timer credentials from $passwords_file"
        return 1
    fi
    
    # Read application secrets
    local jwt_secret=$(yq eval '.application_secrets.jwt_secret' "$passwords_file" 2>/dev/null)
    local countdown_secret_key=$(yq eval '.application_secrets.countdown_secret_key' "$passwords_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_warning "Failed to read application secrets from $passwords_file, will generate new ones"
    fi
    
    # Export variables for use in other functions
    export POSTGRESQL_PASSWORDS="$postgresql_passwords"
    export REDIS_PASSWORD="$redis_password"
    export TIMER_USERNAME="$timer_username"
    export TIMER_PASSWORD="$timer_password"
    export JWT_SECRET="$jwt_secret"
    export COUNTDOWN_SECRET_KEY="$countdown_secret_key"
    
    log_success "Passwords loaded from $passwords_file"
    return 0
}

# Function update_passwords_in_json_files removed - now handled by replace_placeholders

# Function to update image versions in JSON files
update_image_versions_in_json_files() {
    log_info "Updating image versions in JSON files..."
    
    local updated_count=0
    
    # Update each JSON file
    for json_file in "$PROJECT_ROOT"/services/*.json; do
        if [ -f "$json_file" ] && [ "$(basename "$json_file")" != "IMAGES_PLUGIN_VERSION.json" ]; then
            local service_name=$(basename "$json_file" .json)
            local updated=false
            
            # Get current image_repo and image_tag
            local image_repo=$(jq -r '.container.image_repo' "$json_file" 2>/dev/null)
            local current_image_tag=$(jq -r '.container.image_tag' "$json_file" 2>/dev/null)
            
            if [ "$image_repo" != "null" ] && [ -n "$image_repo" ]; then
                # Get new image tag from IMAGES_PLUGIN_VERSION.json
                local new_image_tag=$(get_image_info "$image_repo" 2>/dev/null)
                
                if [ $? -eq 0 ] && [ "$new_image_tag" != "$current_image_tag" ]; then
                    # Update image_tag in JSON file
                    jq --arg new_tag "$new_image_tag" '.container.image_tag = $new_tag' "$json_file" > "$json_file.tmp" && mv "$json_file.tmp" "$json_file"
                    updated=true
                    log_success "Updated image version for $service_name: $current_image_tag -> $new_image_tag"
                fi
            fi
            
            if [ "$updated" = true ]; then
                ((updated_count++))
            fi
        fi
    done
    
    log_success "Updated image versions in $updated_count JSON files"
    return 0
}

# Function update_passwords_in_main_tf removed - now handled by replace_placeholders

# Determine AWS profile
if [ $# -eq 0 ]; then
    # If profile not passed, read from dev.tfvars
    log_info "AWS profile not specified, reading from $PROJECT_ROOT/01-infrastructure/env/dev.tfvars..."
    AWS_PROFILE=$(grep "^aws_profile" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
    if [ -z "$AWS_PROFILE" ]; then
        log_error "Could not find aws_profile in $PROJECT_ROOT/01-infrastructure/env/dev.tfvars"
        exit 1
    fi
    log_info "Found profile: $AWS_PROFILE"
else
    AWS_PROFILE="$1"
fi
export AWS_PROFILE

# Get AWS region from dev.tfvars
log_info "Getting AWS region from $PROJECT_ROOT/01-infrastructure/env/dev.tfvars..."
AWS_REGION=$(grep "^aws_region" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
if [ -z "$AWS_REGION" ]; then
    log_error "Could not find aws_region in $PROJECT_ROOT/01-infrastructure/env/dev.tfvars"
    exit 1
fi

log_info "Updating service configuration from JSON files..."
log_info "AWS Profile: $AWS_PROFILE"
log_info "AWS Region: $AWS_REGION"

# Load passwords from passwords.yml
log_info "Loading passwords from passwords.yml..."
if read_passwords_from_yml; then
    log_success "Passwords loaded from passwords.yml"
    
    # Update image versions in JSON files
    if update_image_versions_in_json_files; then
        log_success "Image versions synchronized in JSON files"
    else
        log_error "Failed to update image versions in JSON files"
        exit 1
    fi
else
    log_error "Failed to load passwords from passwords.yml"
    exit 1
fi

# Check that infrastructure is deployed
if [ ! -f "$PROJECT_ROOT/01-infrastructure/terraform.tfstate" ]; then
    log_error "Error: terraform.tfstate not found in $PROJECT_ROOT/01-infrastructure/"
    log_error "First deploy infrastructure: ./deploy.sh --mode infra --aws_profile $AWS_PROFILE"
    exit 1
fi

# Check services folder exists
if [ ! -d "$PROJECT_ROOT/services" ]; then
    log_error "Services/ folder not found. First create service JSON files"
    exit 1
fi

# Go to infrastructure directory and get outputs
cd "$PROJECT_ROOT/01-infrastructure"

log_info "Getting outputs from infrastructure..."

# Get all necessary values from Terraform outputs
VPC_ID=$(terraform output -raw vpc_id)
PRIVATE_SUBNET_IDS=$(terraform output -json private_subnet_ids)
ECS_CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
ALB_ARN=$(terraform output -raw alb_arn)
LISTENER_ARN=$(terraform output -raw listener_arn)
HTTPS_LISTENER_ARN=$(terraform output -raw https_listener_arn)
EXECUTION_ROLE_ARN=$(terraform output -raw execution_role_arn)
TASK_ROLE_ARN=$(terraform output -raw task_role_arn)
ECS_SG_ID=$(terraform output -raw ecs_sg_id)
CLOUD_MAP_NAMESPACE_ID=$(terraform output -raw cloud_map_namespace_id)

# Get domain from variables
DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "your-domain.example.com")

# Get server IP addresses
POSTGRESQL_PRIVATE_IP=$(terraform output -raw postgresql_private_ip)
REDIS_PRIVATE_IP=$(terraform output -raw redis_private_ip 2>/dev/null || echo "")

# Check if Redis is enabled
ENABLE_REDIS=$(terraform output -raw redis_private_ip 2>/dev/null | grep -q . && echo "true" || echo "false")

# Get Docker Hub secret ARN
DOCKER_HUB_SECRET_ARN=$(terraform output -raw docker_hub_secret_arn)

# Get env_prefix
ENV_PREFIX=$(terraform output -raw env_prefix)

# Get S3 information
S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
S3_BUCKET_REGION=$(terraform output -raw s3_bucket_region 2>/dev/null || echo "")
S3_BASE_DOWNLOAD_URL=$(terraform output -raw s3_base_download_url 2>/dev/null || echo "")
S3_ACCESS_KEY_ID=$(terraform output -raw s3_access_key_id 2>/dev/null || echo "")
S3_SECRET_ACCESS_KEY=$(terraform output -raw s3_secret_access_key 2>/dev/null || echo "")

# Get tags from source of truth - format with proper alignment
TAGS_BLOCK=$(sed -n '/tags = {/,/}/p' env/dev.tfvars | sed '1d;$d' | awk '{
  gsub(/^[ \t]+/, "")  # Remove leading spaces
  split($0, parts, "=")
  if (length(parts) == 2) {
    key = parts[1]
    gsub(/[ \t]+$/, "", key)  # Remove trailing spaces from key
    value = parts[2]
    gsub(/^[ \t]+/, "", value)  # Remove leading spaces from value
    printf "  %-15s = %s\n", key, value
  } else {
    print "  " $0
  }
}')

log_success "Values obtained from infrastructure:"
echo "   VPC ID: $VPC_ID"
echo "   Private Subnets: $PRIVATE_SUBNET_IDS"
echo "   ECS Cluster: $ECS_CLUSTER_NAME"
echo "   ALB ARN: $ALB_ARN"
echo "   PostgreSQL IP: $POSTGRESQL_PRIVATE_IP"
if [ "$ENABLE_REDIS" = "true" ]; then
    echo "   Redis IP: $REDIS_PRIVATE_IP"
else
    echo "   Redis IP: disabled"
fi
echo "   Env Prefix: ${ENV_PREFIX}"

# Return to root directory
cd "$PROJECT_ROOT"

# Create temporary file with updated configuration
log_info "Updating $PROJECT_ROOT/03-services-deploy/env/dev.tfvars..."

# Create backup of original file
cp "$PROJECT_ROOT/03-services-deploy/env/dev.tfvars" "$PROJECT_ROOT/03-services-deploy/env/dev.tfvars.backup"

# Create new file with correct formatting
cat > "$PROJECT_ROOT/03-services-deploy/env/dev.tfvars" << EOF
# aws_profile will be passed from deploy.sh
# aws_region will be automatically determined from aws_profile
aws_profile            = "$AWS_PROFILE"
aws_region             = "$AWS_REGION"
env_prefix             = "${ENV_PREFIX}"

# These values are automatically obtained from infrastructure project outputs:
ecs_cluster_name       = "$ECS_CLUSTER_NAME"
vpc_id                 = "$VPC_ID"
private_subnet_ids     = $PRIVATE_SUBNET_IDS
alb_arn                = "$ALB_ARN"
alb_listener_arn       = "$LISTENER_ARN"
https_listener_arn     = "$HTTPS_LISTENER_ARN"
execution_role_arn     = "$EXECUTION_ROLE_ARN"
task_role_arn          = "$TASK_ROLE_ARN"
ecs_sg_id              = "$ECS_SG_ID"
cloud_map_namespace_id = "$CLOUD_MAP_NAMESPACE_ID"
dockerhub_secret_arn   = "$DOCKER_HUB_SECRET_ARN"

tags = {
$TAGS_BLOCK
}

# ECS Services will be generated from JSON files
ecs_services = {}
EOF

# Now generate main.tf from JSON files
log_info "Generating main.tf from service JSON files..."

# Create backup of original main.tf
cp "$PROJECT_ROOT/03-services-deploy/main.tf" "$PROJECT_ROOT/03-services-deploy/main.tf.backup"

# Start creating new main.tf
cat > "$PROJECT_ROOT/03-services-deploy/main.tf" << 'EOF'
# Get current region
data "aws_region" "current" {}

# CloudWatch Log Groups
EOF

# Generate CloudWatch Log Groups from JSON files
for json_file in "$PROJECT_ROOT"/services/*.json; do
    if [ -f "$json_file" ] && [ "$(basename "$json_file")" != "IMAGES_PLUGIN_VERSION.json" ]; then
        service_name=$(basename "$json_file" .json)
        
        # Read JSON and replace placeholders
        json_content=$(cat "$json_file")
        json_content=$(replace_placeholders "$json_content" "$ENV_PREFIX" "$AWS_REGION" "$POSTGRESQL_PRIVATE_IP" "$REDIS_PRIVATE_IP" "$DOMAIN_NAME" "$S3_ACCESS_KEY_ID" "$S3_SECRET_ACCESS_KEY" "$S3_BUCKET_NAME" "$S3_BUCKET_REGION" "$S3_BASE_DOWNLOAD_URL")
        
        # Extract log group name
        log_group_name=$(echo "$json_content" | jq -r '.cloudwatch_logs.log_group_name')
        
        if [ "$log_group_name" != "null" ] && [ -n "$log_group_name" ]; then
            # Replace underscores with dashes in log group name
            log_group_name_fixed=$(echo "${log_group_name}" | sed 's/_/-/g')
            cat >> "$PROJECT_ROOT/03-services-deploy/main.tf" << EOF

resource "aws_cloudwatch_log_group" "${service_name}" {
  name              = "${log_group_name_fixed}"
  retention_in_days = 7
  tags              = var.tags
}
EOF
        fi
    fi
done

# Generate ALB Target Groups and Listener Rules
cat >> "$PROJECT_ROOT/03-services-deploy/main.tf" << 'EOF'

# ALB Target Groups and Listener Rules
EOF

for json_file in "$PROJECT_ROOT"/services/*.json; do
    if [ -f "$json_file" ] && [ "$(basename "$json_file")" != "IMAGES_PLUGIN_VERSION.json" ]; then
        service_name=$(basename "$json_file" .json)
        
        # Read JSON and replace placeholders
        json_content=$(cat "$json_file")
        json_content=$(replace_placeholders "$json_content" "$ENV_PREFIX" "$AWS_REGION" "$POSTGRESQL_PRIVATE_IP" "$REDIS_PRIVATE_IP" "$DOMAIN_NAME" "$S3_ACCESS_KEY_ID" "$S3_SECRET_ACCESS_KEY" "$S3_BUCKET_NAME" "$S3_BUCKET_REGION" "$S3_BASE_DOWNLOAD_URL")
        
        # Check if target group is needed
        target_group_arn=$(echo "$json_content" | jq -r '.service_config.target_group_arn')
        priority=$(echo "$json_content" | jq -r '.service_config.priority // empty')
        path_patterns=$(echo "$json_content" | jq -r '.service_config.path_patterns // empty')
        container_port=$(echo "$json_content" | jq -r '.container.port_mappings[0].containerPort // 8080')
        
        if [ "$target_group_arn" = "required" ] && [ -n "$priority" ] && [ -n "$path_patterns" ]; then
            # Create target group
            # Replace underscores with dashes for target group name
            tg_name=$(echo "${service_name}" | tr '_' '-')
            
            # Determine health check path depending on service
            health_check_path="/version"
            if [ "$service_name" = "proxy_service" ]; then
                health_check_path="/proxy/version"
            elif [ "$service_name" = "api_gateway" ]; then
                health_check_path="/version"
            elif [ "$service_name" = "countdowntimer" ]; then
                health_check_path="/api/version"
            fi
            
            cat >> "$PROJECT_ROOT/03-services-deploy/main.tf" << EOF

resource "aws_lb_target_group" "${service_name}" {
  name     = "${tg_name}-tg"
  port     = ${container_port}
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"
  health_check {
    path = "${health_check_path}"
    protocol = "HTTP"
  }
  tags = var.tags
}

resource "aws_lb_listener_rule" "${service_name}" {
  listener_arn = var.https_listener_arn
  priority     = ${priority}
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.${service_name}.arn
  }
  condition {
    path_pattern {
      values = ${path_patterns}
    }
  }
}
EOF
        fi
    fi
done

# Generate ECS Services
cat >> "$PROJECT_ROOT/03-services-deploy/main.tf" << 'EOF'

# ECS Services
EOF

for json_file in "$PROJECT_ROOT"/services/*.json; do
    if [ -f "$json_file" ] && [ "$(basename "$json_file")" != "IMAGES_PLUGIN_VERSION.json" ]; then
        service_name=$(basename "$json_file" .json)
        
        # Read JSON and replace placeholders
        json_content=$(cat "$json_file")
        json_content=$(replace_placeholders "$json_content" "$ENV_PREFIX" "$AWS_REGION" "$POSTGRESQL_PRIVATE_IP" "$REDIS_PRIVATE_IP" "$DOMAIN_NAME" "$S3_ACCESS_KEY_ID" "$S3_SECRET_ACCESS_KEY" "$S3_BUCKET_NAME" "$S3_BUCKET_REGION" "$S3_BASE_DOWNLOAD_URL")
        
        # Extract data from JSON
        display_name=$(echo "$json_content" | jq -r '.display_name')
        container_name=$(echo "$json_content" | jq -r '.container.name')
        image_repo=$(echo "$json_content" | jq -r '.container.image_repo')
        image_tag=$(echo "$json_content" | jq -r '.container.image_tag')
        cpu=$(echo "$json_content" | jq -r '.container.cpu')
        memory=$(echo "$json_content" | jq -r '.container.memory')
        init_process_enabled=$(echo "$json_content" | jq -r '.container.initProcessEnabled // false')
        desired_count=$(echo "$json_content" | jq -r '.service_config.desired_count')
        target_group_arn=$(echo "$json_content" | jq -r '.service_config.target_group_arn')
        container_port=$(echo "$json_content" | jq -r '.container.port_mappings[0].containerPort // 8080')
        
        # Check if need to update image_tag from images_plugin_version.json
        new_image_tag=$(get_image_info "$image_repo" 2>/dev/null || echo "$image_tag")
        
        # Create environment variables
        environment_json=$(echo "$json_content" | jq -r '.environment // []')
        
        # Create port mappings
        port_mappings_json=$(echo "$json_content" | jq -r '.container.port_mappings // []')
        
        # Create health check if exists
        health_check_json=$(echo "$json_content" | jq -r '.container.health_check // null')
        
        # Determine target_group_arn for module
        if [ "$target_group_arn" = "required" ]; then
            target_group_arn_value="aws_lb_target_group.${service_name}.arn"
        else
            target_group_arn_value="null"
        fi
        
        cat >> "$PROJECT_ROOT/03-services-deploy/main.tf" << EOF

module "ecs_service_${service_name}" {
  source                = "./modules/ecs_service"
  cluster_id            = var.ecs_cluster_name
  family                = "${container_name}"
  cpu                   = ${cpu}
  memory                = ${memory}
  execution_role_arn    = var.execution_role_arn
  task_role_arn         = var.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "${container_name}"
      image     = "${image_repo}:${new_image_tag}"
      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }
      cpu       = ${cpu}
      memory    = ${memory}
      essential = true
      portMappings = ${port_mappings_json}
      environment = ${environment_json}
EOF

        # Add linuxParameters if initProcessEnabled is true
        if [ "$init_process_enabled" = "true" ]; then
            cat >> "$PROJECT_ROOT/03-services-deploy/main.tf" << EOF
      linuxParameters = {
        initProcessEnabled = true
      }
EOF
        fi

        cat >> "$PROJECT_ROOT/03-services-deploy/main.tf" << EOF
              logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/\${var.env_prefix}-${service_name//_/-}"
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "${service_name}"
          }
        }
EOF

        # Add health check if exists
        if [ "$health_check_json" != "null" ]; then
            cat >> "$PROJECT_ROOT/03-services-deploy/main.tf" << EOF
      healthCheck = ${health_check_json}
EOF
        fi

        cat >> "$PROJECT_ROOT/03-services-deploy/main.tf" << EOF
    }
  ])
  service_name      = "${container_name}"
  subnets           = var.private_subnet_ids
  ecs_sg_id         = var.ecs_sg_id
  target_group_arn  = ${target_group_arn_value}
  alb_listener_arn  = var.https_listener_arn
  container_name    = "${container_name}"
  container_port    = ${container_port}
  desired_count     = ${desired_count}
  tags              = var.tags
  cloud_map_namespace_id = var.cloud_map_namespace_id
}
EOF
    fi
    done

# Passwords are now handled by placeholder replacement in main.tf generation
log_success "Passwords automatically synchronized via placeholder replacement"

log_success "Configuration updated successfully!"
log_info "Backup saved in: $PROJECT_ROOT/03-services-deploy/env/dev.tfvars.backup"
log_info "Backup main.tf saved in: $PROJECT_ROOT/03-services-deploy/main.tf.backup"

# Update test_index.html with actual domain
echo ""
log_info "🔄 Updating test_index.html with domain: $DOMAIN_NAME"

if [ -f "$PROJECT_ROOT/test_index.html" ]; then
    # Create backup
    cp "$PROJECT_ROOT/test_index.html" "$PROJECT_ROOT/test_index.html.backup"
    
    # Update domain in file
    sed -i.bak "s|https://your-domain.example.com|https://$DOMAIN_NAME|g" "$PROJECT_ROOT/test_index.html"
    
    # Check that changes were applied
    if grep -q "https://$DOMAIN_NAME" "$PROJECT_ROOT/test_index.html"; then
        log_success "test_index.html updated successfully"
        log_info "Backup saved in: $PROJECT_ROOT/test_index.html.backup"
        
        # Show changes
        echo "📝 Changes in test_index.html:"
        grep -n "https://$DOMAIN_NAME" "$PROJECT_ROOT/test_index.html" | head -3
    else
        log_warning "Could not update domain in test_index.html"
        # Restore from backup
        mv "$PROJECT_ROOT/test_index.html.backup" "$PROJECT_ROOT/test_index.html"
    fi
    
    # Remove temporary file
    rm -f "$PROJECT_ROOT/test_index.html.bak"
else
    log_warning "File test_index.html not found"
fi

echo ""
echo "🔄 Now you can deploy services:"
echo "   ./deploy.sh --mode services --aws_profile $AWS_PROFILE"
