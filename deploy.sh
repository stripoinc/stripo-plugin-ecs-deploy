#!/bin/bash

# Stripo Plugin ECS Project - Main deployment script
# Execution order: 01-infrastructure → 02-servers-bootstrap → 03-services-deploy

set -e

# Default variables
MODE=""
AWS_PROFILE=""
SSH_ACCESS_CIDR=""

# Determine project root directory (works from any subdirectory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Command line argument parsing
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                MODE="$2"
                shift 2
                ;;
            --aws_profile)
                AWS_PROFILE="$2"
                shift 2
                ;;
            --ssh_cidr)
                SSH_ACCESS_CIDR="$2"
                shift 2
                ;;
            --auto_my_ip)
                MY_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")
                if [ -n "$MY_IP" ]; then
                    SSH_ACCESS_CIDR="$MY_IP/32"
                    log_info "IP automatically detected: $MY_IP"
                else
                    log_error "Failed to determine IP address"
                    exit 1
                fi
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Required parameters check
    if [ -z "$MODE" ]; then
        log_error "Mode not specified (--mode)"
        show_help
        exit 1
    fi
    
    # AWS_PROFILE is optional - will be auto-read from dev.tfvars if not specified
    
    # Mode validation
    case $MODE in
        full|infra|bootstrap-servers|services|check|status|monitor|cleanup|register-plugin|configure-countdown-timer)
            ;;
        *)
            log_error "Invalid mode: $MODE. Available: full, infra, bootstrap-servers, services, check, status, monitor, cleanup, register-plugin, configure-countdown-timer"
            show_help
            exit 1
            ;;
    esac
}

# Show help
show_help() {
    echo "Stripo Plugin ECS Project - Deployment script"
    echo ""
    echo "Usage:"
    echo "  ./deploy.sh --mode <mode> [--aws_profile <profile>] [--ssh_cidr <ip/cidr> | --auto_my_ip]"
    echo ""
    echo "Modes:"
    echo "  full                      - Full deployment (infra + bootstrap-servers + services)"
    echo "  infra                     - Infrastructure only (including ECS Exec policies)"
    echo "  bootstrap-servers         - Server bootstrap only (PostgreSQL, Redis)"
    echo "  services                  - ECS services only"
    echo "  register-plugin           - Test plugin registration only"
    echo "  configure-countdown-timer - Countdown Timer configuration only"
    echo "  check                     - Check dependencies, AWS profile and show requirements"
    echo "  status                    - Check deployment status"
    echo "  monitor                   - Monitor services progress (real-time)"
    echo "  cleanup                   - Remove all resources"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh --mode full --auto_my_ip"
    echo "  ./deploy.sh --mode infra --aws_profile dev --ssh_cidr 192.168.1.100/32"
    echo "  ./deploy.sh --mode bootstrap-servers"
    echo ""
    echo "Options:"
    echo "  --aws_profile <profile>   - AWS profile (optional, auto-reads from dev.tfvars)"
    echo "  --ssh_cidr <ip/cidr>      - IP address for SSH access to Bastion (e.g.: 1.2.3.4/32)"
    echo "  --auto_my_ip              - Automatically determine your IP for Bastion SSH access"
    echo "  -h, --help                - Show this help"
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    # Core tools
    local missing_tools=()
    
    # Infrastructure tools
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws")
    fi
    
    # Configuration management
    if ! command -v ansible-playbook &> /dev/null; then
        missing_tools+=("ansible")
    fi
    
    # JSON processing
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    # Network tools
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if ! command -v ssh &> /dev/null; then
        missing_tools+=("ssh")
    fi
    
    if ! command -v ssh-keyscan &> /dev/null; then
        missing_tools+=("ssh-keyscan")
    fi
    
    # Check for netcat (nc, netcat, or ncat)
    if ! command -v nc &> /dev/null && ! command -v netcat &> /dev/null && ! command -v ncat &> /dev/null; then
        missing_tools+=("netcat")
    fi
    
    # Additional tools used in scripts
    if ! command -v yq &> /dev/null; then
        missing_tools+=("yq")
    fi
    
    if ! command -v openssl &> /dev/null; then
        missing_tools+=("openssl")
    fi
    
    if ! command -v timeout &> /dev/null; then
        missing_tools+=("timeout")
    fi
    

    
    # Check for missing tools
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Installation instructions:"
        echo "  macOS (Homebrew):"
        echo "    brew install terraform awscli ansible jq curl netcat yq openssl coreutils"
        echo ""
        echo "  Ubuntu/Debian:"
        echo "    sudo apt update && sudo apt install -y terraform awscli ansible jq curl netcat-openbsd yq openssl coreutils"
        echo ""
        echo "  CentOS/RHEL/Fedora:"
        echo "    sudo yum install -y terraform awscli ansible jq curl nc yq openssl coreutils"
        echo "    # or for newer systems:"
        echo "    sudo dnf install -y terraform awscli ansible jq curl nc yq openssl coreutils"
        echo ""
        echo "  Alpine Linux:"
        echo "    apk add terraform aws-cli ansible jq curl netcat-openbsd yq openssl coreutils"
        echo ""
        echo "  Arch Linux:"
        echo "    sudo pacman -S terraform aws-cli ansible jq curl netcat yq openssl coreutils"
        exit 1
    fi
    

    
    log_success "All required dependencies are installed"
}

# Check AWS profile
check_aws_profile() {
    log_info "Checking AWS profile..."
    
    if [ -z "$AWS_PROFILE" ]; then
        # If profile not specified, read from dev.tfvars
        log_info "AWS_PROFILE not specified, reading from $PROJECT_ROOT/01-infrastructure/env/dev.tfvars..."
        if [ -f "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" ]; then
            AWS_PROFILE=$(grep "^aws_profile" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
            if [ -z "$AWS_PROFILE" ]; then
                log_error "Cannot find aws_profile in $PROJECT_ROOT/01-infrastructure/env/dev.tfvars"
                log_info "Available profiles:"
                aws configure list-profiles
                exit 1
            fi
            log_info "Found profile in dev.tfvars: $AWS_PROFILE"
        else
            log_error "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars not found"
            log_info "Available profiles:"
            aws configure list-profiles
            exit 1
        fi
    fi
    
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
        log_error "Cannot connect to AWS. Check profile: $AWS_PROFILE"
        log_info "Available profiles:"
        aws configure list-profiles
        exit 1
    fi
    
    # Get region from dev.tfvars
    current_region=$(grep "^aws_region" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
    if [ -z "$current_region" ]; then
        current_region="not set"
    fi
    
    account_id=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query 'Account' --output text)
    
    log_success "AWS profile configured: $AWS_PROFILE"
    log_info "Region: $current_region"
    log_info "Account: $account_id"
}

# Show deployment checklist
show_checklist() {
    echo ""
    echo "=========================================="
    echo "🚀 STRIPO PLUGIN ECS PROJECT - CHECKLIST"
    echo "=========================================="
    echo ""
    
    # Check current status
    local terraform_ok=false
    local aws_ok=false
    local ansible_ok=false
    local jq_ok=false
    local curl_ok=false
    local ssh_ok=false
    local nc_ok=false
    local yq_ok=false
    local openssl_ok=false
    local timeout_ok=false
    
    # Check tools and get versions
    command -v terraform &> /dev/null && terraform_ok=true
    command -v aws &> /dev/null && aws_ok=true
    command -v ansible-playbook &> /dev/null && ansible_ok=true
    command -v jq &> /dev/null && jq_ok=true
    command -v curl &> /dev/null && curl_ok=true
    command -v ssh &> /dev/null && ssh_ok=true
    command -v nc &> /dev/null && nc_ok=true
    command -v yq &> /dev/null && yq_ok=true
    command -v openssl &> /dev/null && openssl_ok=true
    command -v timeout &> /dev/null && timeout_ok=true
    
    # Get versions for installed tools
    terraform_version=""
    aws_version=""
    ansible_version=""
    jq_version=""
    yq_version=""
    openssl_version=""
    curl_version=""
    ssh_version=""
    nc_version=""
    timeout_version=""
    
    if [ "$terraform_ok" = true ]; then
        terraform_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    fi
    
    if [ "$aws_ok" = true ]; then
        aws_version=$(aws --version 2>/dev/null | sed 's/aws-cli\///' | sed 's/ Python.*//' | sed 's/ .*//' || echo "unknown")
    fi
    
    if [ "$ansible_ok" = true ]; then
        ansible_version=$(ansible --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    fi
    
    if [ "$jq_ok" = true ]; then
        jq_version=$(jq --version 2>/dev/null | sed 's/jq-//' || echo "unknown")
    fi
    
    if [ "$yq_ok" = true ]; then
        yq_version=$(yq --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    fi
    
    if [ "$openssl_ok" = true ]; then
        openssl_version=$(openssl version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    fi
    
    if [ "$curl_ok" = true ]; then
        curl_version=$(curl --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    fi
    
    if [ "$ssh_ok" = true ]; then
        ssh_version=$(ssh -V 2>&1 | grep -o '[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    fi
    
    if [ "$nc_ok" = true ]; then
        nc_version=$(nc -h 2>&1 | grep -o '[0-9]\+\.[0-9]\+' | head -1 || echo "system")
    fi
    
    if [ "$timeout_ok" = true ]; then
        timeout_version=$(timeout --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1 || echo "system")
    fi
    
    # Check AWS profile
    local aws_profile_ok=false
    local aws_profile=""
    if [ -f "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" ]; then
        aws_profile=$(grep "^aws_profile" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
        if [ -n "$aws_profile" ] && aws sts get-caller-identity --profile "$aws_profile" &> /dev/null; then
            aws_profile_ok=true
        fi
    fi
    
    # Check AWS permissions
    local ec2_ok=false
    local vpc_ok=false
    local iam_ok=false
    local ecs_ok=false
    local alb_ok=false
    local s3_ok=false
    local secrets_ok=false
    local cloudwatch_ok=false
    local route53_ok=false
    local ssm_ok=false
    
    if [ "$aws_profile_ok" = true ]; then
        log_info "Checking AWS permissions (this may take a moment)..."
        
        # Get region from dev.tfvars
        local aws_region=$(grep "^aws_region" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
        if [ -z "$aws_region" ]; then
            aws_region="us-east-1"  # fallback
        fi
        
        # Test EC2 permissions (try multiple commands)
        if timeout 10 aws ec2 describe-regions --profile "$aws_profile" --region "$aws_region" &> /dev/null || \
           timeout 10 aws ec2 describe-instances --profile "$aws_profile" --region "$aws_region" &> /dev/null; then
            ec2_ok=true
        fi
        
        # Test VPC permissions (VPC is part of EC2 service)
        if timeout 10 aws ec2 describe-vpcs --profile "$aws_profile" --region "$aws_region" &> /dev/null; then
            vpc_ok=true
        fi
        
        # Test IAM permissions (IAM is global, no region needed)
        if timeout 10 aws iam get-user --profile "$aws_profile" &> /dev/null || \
           timeout 10 aws iam list-users --profile "$aws_profile" &> /dev/null; then
            iam_ok=true
        fi
        
        # Test ECS permissions
        if timeout 10 aws ecs list-clusters --profile "$aws_profile" --region "$aws_region" &> /dev/null; then
            ecs_ok=true
        fi
        
        # Test ALB permissions (ELBv2)
        if timeout 10 aws elbv2 describe-load-balancers --profile "$aws_profile" --region "$aws_region" &> /dev/null; then
            alb_ok=true
        fi
        
        # Test S3 permissions (S3 is global)
        if timeout 10 aws s3 ls --profile "$aws_profile" &> /dev/null; then
            s3_ok=true
        fi
        
        # Test Secrets Manager permissions
        if timeout 10 aws secretsmanager list-secrets --profile "$aws_profile" --region "$aws_region" &> /dev/null; then
            secrets_ok=true
        fi
        
        # Test CloudWatch permissions
        if timeout 10 aws logs describe-log-groups --profile "$aws_profile" --region "$aws_region" &> /dev/null; then
            cloudwatch_ok=true
        fi
        
        # Test Route 53 permissions (Route53 is global)
        if timeout 10 aws route53 list-hosted-zones --profile "$aws_profile" &> /dev/null; then
            route53_ok=true
        fi
        
        # Test SSM permissions
        if timeout 10 aws ssm describe-instance-information --profile "$aws_profile" --region "$aws_region" &> /dev/null; then
            ssm_ok=true
        fi
        
        log_success "AWS permissions check completed"
    fi
    
    # Check infrastructure status
    local infra_ok=false
    if [ -f "$PROJECT_ROOT/01-infrastructure/terraform.tfstate" ]; then
        local resource_count=$(jq '.resources | length' "$PROJECT_ROOT/01-infrastructure/terraform.tfstate" 2>/dev/null || echo "0")
        if [ "$resource_count" -gt 0 ]; then
            infra_ok=true
        fi
    fi
    
    # Check services status
    local services_ok=false
    if [ -f "$PROJECT_ROOT/03-services-deploy/terraform.tfstate" ]; then
        local resource_count=$(jq '.resources | length' "$PROJECT_ROOT/03-services-deploy/terraform.tfstate" 2>/dev/null || echo "0")
        if [ "$resource_count" -gt 0 ]; then
            services_ok=true
        fi
    fi
    
    echo "☁️  AWS CONFIGURATION:"
    echo ""
    printf "%-10s %-25s %-20s %s\n" "Status" "Setting" "Value" "Description"
    printf "%-10s %-25s %-20s %s\n" "------" "-------" "-----" "-----------"
    printf "%-10s %-25s %-20s %s\n" "$([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐")" "Profile" "$([ "$aws_profile_ok" = true ] && echo "$(grep "^aws_profile" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')" || echo "-")" "AWS CLI profile"
    printf "%-10s %-25s %-20s %s\n" "$([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐")" "Region" "$([ "$aws_profile_ok" = true ] && echo "$(grep "^aws_region" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')" || echo "-")" "AWS region"
    printf "%-10s %-25s %-20s %s\n" "$([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐")" "Account" "$([ "$aws_profile_ok" = true ] && echo "$(aws sts get-caller-identity --profile "$(grep "^aws_profile" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')" --query 'Account' --output text 2>/dev/null)" || echo "-")" "AWS account ID"
    echo ""
    
    echo "📋 PREREQUISITES CHECKLIST:"
    echo ""
    printf "%-10s %-25s %-20s %s\n" "Status" "Tool" "Version" "Description"
    printf "%-10s %-25s %-20s %s\n" "------" "----" "-------" "-----------"
    printf "%-10s %-25s %-20s %s\n" "$([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐")" "AWS Account" "-" "With appropriate permissions"
    printf "%-10s %-25s %-20s %s\n" "$([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐")" "AWS CLI" "$([ "$aws_profile_ok" = true ] && echo "$aws_version" || echo "-")" "Configured with profile"
    printf "%-10s %-25s %-20s %s\n" "$([ "$terraform_ok" = true ] && echo "✅" || echo "☐")" "Terraform" "$([ "$terraform_ok" = true ] && echo "$terraform_version" || echo "-")" "Infrastructure as Code"
    printf "%-10s %-25s %-20s %s\n" "$([ "$ansible_ok" = true ] && echo "✅" || echo "☐")" "Ansible" "$([ "$ansible_ok" = true ] && echo "$ansible_version" || echo "-")" "Configuration management"
    printf "%-10s %-25s %-20s %s\n" "$([ "$jq_ok" = true ] && echo "✅" || echo "☐")" "jq" "$([ "$jq_ok" = true ] && echo "$jq_version" || echo "-")" "JSON processing"
    printf "%-10s %-25s %-20s %s\n" "$([ "$yq_ok" = true ] && echo "✅" || echo "☐")" "yq" "$([ "$yq_ok" = true ] && echo "$yq_version" || echo "-")" "YAML processing"
    printf "%-10s %-25s %-20s %s\n" "$([ "$curl_ok" = true ] && echo "✅" || echo "☐")" "curl" "$([ "$curl_ok" = true ] && echo "$curl_version" || echo "-")" "HTTP requests"
    printf "%-10s %-25s %-20s %s\n" "$([ "$ssh_ok" = true ] && echo "✅" || echo "☐")" "SSH" "$([ "$ssh_ok" = true ] && echo "$ssh_version" || echo "-")" "Remote access"
    printf "%-10s %-25s %-20s %s\n" "$([ "$nc_ok" = true ] && echo "✅" || echo "☐")" "netcat" "$([ "$nc_ok" = true ] && echo "$nc_version" || echo "-")" "Port testing"
    printf "%-10s %-25s %-20s %s\n" "$([ "$openssl_ok" = true ] && echo "✅" || echo "☐")" "openssl" "$([ "$openssl_ok" = true ] && echo "$openssl_version" || echo "-")" "Secret generation"
    printf "%-10s %-25s %-20s %s\n" "$([ "$timeout_ok" = true ] && echo "✅" || echo "☐")" "timeout" "$([ "$timeout_ok" = true ] && echo "$timeout_version" || echo "-")" "Command timeouts"
    echo ""
    
    echo "🔧 REQUIRED AWS PERMISSIONS:"
    echo ""
    printf "%-10s %-25s %s\n" "Status" "Service" "Permissions Required"
    printf "%-10s %-25s %s\n" "------" "-------" "--------------------"
    printf "%-10s %-25s %s\n" "$([ "$ec2_ok" = true ] && echo "✅" || echo "☐")" "EC2" "Create/Delete instances, security groups, key pairs"
    printf "%-10s %-25s %s\n" "$([ "$vpc_ok" = true ] && echo "✅" || echo "☐")" "VPC" "Create/Delete VPC, subnets, route tables, IGW"
    printf "%-10s %-25s %s\n" "$([ "$iam_ok" = true ] && echo "✅" || echo "☐")" "IAM" "Create/Delete roles, policies, instance profiles"
    printf "%-10s %-25s %s\n" "$([ "$ecs_ok" = true ] && echo "✅" || echo "☐")" "ECS" "Create/Delete cluster, services, task definitions"
    printf "%-10s %-25s %s\n" "$([ "$alb_ok" = true ] && echo "✅" || echo "☐")" "ALB" "Create/Delete load balancer, target groups"
    printf "%-10s %-25s %s\n" "$([ "$s3_ok" = true ] && echo "✅" || echo "☐")" "S3" "Create/Delete bucket for Terraform state"
    printf "%-10s %-25s %s\n" "$([ "$secrets_ok" = true ] && echo "✅" || echo "☐")" "Secrets Manager" "Create/Delete secrets"
    printf "%-10s %-25s %s\n" "$([ "$cloudwatch_ok" = true ] && echo "✅" || echo "☐")" "CloudWatch" "Create/Delete log groups"
    printf "%-10s %-25s %s\n" "$([ "$ssm_ok" = true ] && echo "✅" || echo "☐")" "SSM" "Session Manager access to EC2 instances"
    printf "%-10s %-25s %s\n" "$([ "$route53_ok" = true ] && echo "🔶" || echo "⚪")" "Route 53 (optional)" "Custom domain DNS (can use ALB DNS directly)"
    echo ""
    
    echo "📁 PROJECT STRUCTURE:"
    echo ""
    printf "%-10s %-35s %s\n" "Status" "Directory/File" "Description"
    printf "%-10s %-35s %s\n" "------" "---------------" "-----------"
    printf "%-10s %-35s %s\n" "✅" "01-infrastructure/" "Terraform infrastructure code"
    printf "%-10s %-35s %s\n" "✅" "02-servers-bootstrap/" "Ansible playbooks for server setup"
    printf "%-10s %-35s %s\n" "✅" "03-services-deploy/" "Terraform ECS services deployment"
    printf "%-10s %-35s %s\n" "✅" "services/" "JSON configuration files for services"
    printf "%-10s %-35s %s\n" "✅" "deploy.sh" "Main deployment script"
    printf "%-10s %-35s %s\n" "✅" "update_services_config.sh" "Service configuration generator"
    printf "%-10s %-35s %s\n" "✅" "connect_fargate.sh" "Connect to ECS Fargate containers"
    printf "%-10s %-35s %s\n" "✅" "connect_instances.sh" "Connect to EC2 instances via SSM"
    echo ""
    
    echo "🚀 DEPLOYMENT STATUS:"
    echo ""
    printf "%-10s %-25s %s\n" "Status" "Component" "Description"
    printf "%-10s %-25s %s\n" "------" "---------" "-----------"
    printf "%-10s %-25s %s\n" "$([ "$infra_ok" = true ] && echo "✅" || echo "☐")" "Infrastructure" "VPC, EC2, ECS, ALB, IAM"
    printf "%-10s %-25s %s\n" "$([ "$services_ok" = true ] && echo "✅" || echo "☐")" "Services" "17 microservices on ECS"
    echo ""
    
    echo "📋 NEXT STEPS:"
    if [ "$infra_ok" = false ] && [ "$services_ok" = false ]; then
        echo "  🚀 Start with full deployment:"
        echo "     ./deploy.sh --mode full --auto_my_ip"
        echo ""
        echo "  📝 Or deploy step by step:"
        echo "     1. ./deploy.sh --mode infra --auto_my_ip"
        echo "     2. ./deploy.sh --mode bootstrap-servers"
        echo "     3. ./deploy.sh --mode services"
    elif [ "$infra_ok" = true ] && [ "$services_ok" = false ]; then
        echo "  🔧 Continue with servers and services:"
        echo "     1. ./deploy.sh --mode bootstrap-servers"
        echo "     2. ./deploy.sh --mode services"
    elif [ "$infra_ok" = true ] && [ "$services_ok" = true ]; then
        echo "  ✅ Deployment complete! Available commands:"
        echo "     ./deploy.sh --mode status    # Check status"
        echo "     ./deploy.sh --mode monitor   # Monitor services"
        echo "     ./deploy.sh --mode cleanup   # Remove all resources"
    fi
    
    echo ""
    echo "=========================================="
    echo ""
}

# Old function (keep for reference)
show_checklist_old() {
    echo ""
    echo "=========================================="
    echo "🚀 STRIPO PLUGIN ECS PROJECT - CHECKLIST"
    echo "=========================================="
    echo ""
    
    # Check current status
    local terraform_ok=false
    local aws_ok=false
    local ansible_ok=false
    local jq_ok=false
    local curl_ok=false
    local ssh_ok=false
    local nc_ok=false
    local psql_ok=false
    local redis_ok=false
    
    # Check tools
    command -v terraform &> /dev/null && terraform_ok=true
    command -v aws &> /dev/null && aws_ok=true
    command -v ansible-playbook &> /dev/null && ansible_ok=true
    command -v jq &> /dev/null && jq_ok=true
    command -v curl &> /dev/null && curl_ok=true
    command -v ssh &> /dev/null && ssh_ok=true
    command -v nc &> /dev/null && nc_ok=true
    command -v psql &> /dev/null && psql_ok=true
    command -v redis-cli &> /dev/null && redis_ok=true
    
    # Check AWS profile
    local aws_profile_ok=false
            if [ -f "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" ]; then
            local profile=$(grep "^aws_profile" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
        if [ -n "$profile" ] && aws sts get-caller-identity --profile "$profile" &> /dev/null; then
            aws_profile_ok=true
        fi
    fi
    
    # Check infrastructure status
    local infra_ok=false
            if [ -f "$PROJECT_ROOT/01-infrastructure/terraform.tfstate" ]; then
        infra_ok=true
    fi
    
    # Check services status
    local services_ok=false
    if [ -f "03-services-deploy/terraform.tfstate" ]; then
        services_ok=true
    fi
    
    echo "📋 PREREQUISITES CHECKLIST:"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") AWS Account with appropriate permissions"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") AWS CLI configured with profile"
    echo "  $([ "$terraform_ok" = true ] && echo "✅" || echo "☐") Terraform installed (v1.0+)"
    echo "  $([ "$ansible_ok" = true ] && echo "✅" || echo "☐") Ansible installed (v2.9+)"
    echo "  $([ "$jq_ok" = true ] && echo "✅" || echo "☐") jq installed for JSON processing"
    echo "  $([ "$curl_ok" = true ] && echo "✅" || echo "☐") curl installed for HTTP requests"
    echo "  $([ "$ssh_ok" = true ] && echo "✅" || echo "☐") SSH client installed"
    echo "  $([ "$nc_ok" = true ] && echo "✅" || echo "☐") netcat installed for port testing"
    echo "  $([ "$psql_ok" = true ] && echo "✅" || echo "☐") psql (PostgreSQL client) - recommended"
    echo "  $([ "$redis_ok" = true ] && echo "✅" || echo "☐") redis-cli - recommended"
    echo ""
    
    echo "🔧 REQUIRED AWS PERMISSIONS:"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") EC2: Create/Delete instances, security groups, key pairs"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") VPC: Create/Delete VPC, subnets, route tables, internet gateway"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") IAM: Create/Delete roles, policies, instance profiles"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") ECS: Create/Delete cluster, services, task definitions"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") ALB: Create/Delete load balancer, target groups, listeners"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") S3: Create/Delete bucket for Terraform state"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") Secrets Manager: Create/Delete secrets"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") CloudWatch: Create/Delete log groups"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") Route 53: Update DNS records (if using custom domain)"
    echo "  $([ "$aws_profile_ok" = true ] && echo "✅" || echo "☐") SSM: Session Manager access to EC2 instances"
    echo ""
    
    echo "📁 PROJECT STRUCTURE:"
    echo "  ✅ 01-infrastructure/ - Terraform infrastructure code"
    echo "  ✅ 02-servers-bootstrap/ - Ansible playbooks for server setup"
    echo "  ✅ 03-services-deploy/ - Terraform ECS services deployment"
    echo "  ✅ services/ - JSON configuration files for services"
    echo "  ✅ deploy.sh - Main deployment script"
    echo "  ✅ update_services_config.sh - Service configuration generator"
    echo ""
    

    

    

    

    
    echo "=========================================="
    echo ""
    

}

# Step 1: Create infrastructure
deploy_infrastructure() {
    log_info "🚀 Step 1: Creating AWS infrastructure"
    
    cd "$PROJECT_ROOT/01-infrastructure"
    
    log_info "Initializing Terraform..."
    terraform init
    
    # Prepare variables for Terraform
    terraform_vars="-var-file=env/dev.tfvars"
    
    # Get region from dev.tfvars and pass to Terraform
    AWS_REGION=$(grep "^aws_region" env/dev.tfvars | cut -d'=' -f2 | tr -d ' "')
    if [ -n "$AWS_REGION" ]; then
        terraform_vars="$terraform_vars -var=aws_region=$AWS_REGION"
        log_info "AWS Region: $AWS_REGION"
        
        # Determine AZs for region (simply add a and b)
        AZS="[\"${AWS_REGION}a\", \"${AWS_REGION}b\"]"
        
        # Create temporary file with AZs
        echo "azs = $AZS" > env/temp_azs.tfvars
        terraform_vars="$terraform_vars -var-file=env/temp_azs.tfvars"
        log_info "Availability Zones: $AZS"
    else
        log_error "aws_region not found in env/dev.tfvars"
        exit 1
    fi
    
    if [ -n "$SSH_ACCESS_CIDR" ]; then
        terraform_vars="$terraform_vars -var=ssh_access_cidr=$SSH_ACCESS_CIDR"
        log_info "SSH access: $SSH_ACCESS_CIDR"
    fi
    
    # Check if Redis should be enabled based on RATE_LIMIT_ENABLED
    if [ -f "$PROJECT_ROOT/services/api_gateway.json" ]; then
        RATE_LIMIT_ENABLED=$(jq -r '.environment[] | select(.name=="RATE_LIMIT_ENABLED") | .value' "$PROJECT_ROOT/services/api_gateway.json" 2>/dev/null || echo "false")
        ENABLE_REDIS=$([ "$RATE_LIMIT_ENABLED" = "true" ] && echo "true" || echo "false")
        terraform_vars="$terraform_vars -var=enable_redis=$ENABLE_REDIS"
        log_info "Rate limiting enabled: $RATE_LIMIT_ENABLED"
        log_info "Redis enabled: $ENABLE_REDIS"
    else
        log_warning "api_gateway.json not found, using default Redis enabled=true"
        terraform_vars="$terraform_vars -var=enable_redis=true"
    fi
    
    log_info "Planning changes..."
    terraform plan $terraform_vars
    
    read -p "Apply changes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Applying changes..."
        terraform apply $terraform_vars -auto-approve
        
        log_info "Saving SSH keys..."
        ./save_ssh_keys.sh
        
        log_info "Setting up ECS Exec policies..."
        cd "$PROJECT_ROOT/02-servers-bootstrap"
        # Get env_prefix and tags from Terraform outputs
        cd "$PROJECT_ROOT/01-infrastructure"
        ENV_PREFIX=$(terraform output -raw env_prefix 2>/dev/null || echo "plugin-ecs-dev")
        TAGS_JSON=$(terraform output -json tags 2>/dev/null || echo '{}')
        cd "$PROJECT_ROOT/02-servers-bootstrap"
        AWS_PROFILE="$AWS_PROFILE" AWS_REGION="$AWS_REGION" ansible-playbook playbooks/setup_ecs_exec.yml -e "env_prefix=$ENV_PREFIX aws_profile=$AWS_PROFILE aws_region=$AWS_REGION tags='$TAGS_JSON'"
        cd "$PROJECT_ROOT/01-infrastructure"
        
        log_success "Infrastructure created"
    else
        log_warning "Infrastructure creation skipped"
    fi
    
    cd "$PROJECT_ROOT"
}

# Step 2: Bootstrap servers
bootstrap_servers() {
    log_info "🔧 Step 2: Server bootstrap"
    
    # Automatic configuration update from passwords.yml
    log_info "🔄 Automatic password synchronization from passwords.yml..."
    cd "$PROJECT_ROOT"
    if [ -f "update_services_config.sh" ]; then
        ./update_services_config.sh "$AWS_PROFILE"
        if [ $? -eq 0 ]; then
            log_success "Passwords synchronized from passwords.yml"
        else
            log_error "Error synchronizing passwords"
            exit 1
        fi
    else
        log_warning "Script update_services_config.sh not found, using existing configuration"
    fi
    
    cd "$PROJECT_ROOT/02-servers-bootstrap"
    
    # Check SSH keys
    if [ ! -f "$PROJECT_ROOT/ssh_keys/stripo-ansible-key" ]; then
        log_error "SSH keys not found. First run Step 1"
        exit 1
    fi
    
    # Set key permissions
    chmod 600 "$PROJECT_ROOT/ssh_keys/stripo-ansible-key"
    chmod 644 "$PROJECT_ROOT/ssh_keys/stripo-ansible-key.pub"
    
    # Add hosts to known_hosts for automatic connection
    log_info "Adding hosts to known_hosts..."
    cd "$PROJECT_ROOT/01-infrastructure"
    BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
    cd "$PROJECT_ROOT/02-servers-bootstrap"
    if [ ! -z "$BASTION_IP" ]; then
        ssh-keyscan -H "$BASTION_IP" >> ~/.ssh/known_hosts 2>/dev/null || true
    fi

    # Determine if Redis should be enabled based on RATE_LIMIT_ENABLED
    if [ -f "$PROJECT_ROOT/services/api_gateway.json" ]; then
        RATE_LIMIT_ENABLED=$(jq -r '.environment[] | select(.name=="RATE_LIMIT_ENABLED") | .value' "$PROJECT_ROOT/services/api_gateway.json" 2>/dev/null || echo "false")
        ENABLE_REDIS=$([ "$RATE_LIMIT_ENABLED" = "true" ] && echo "true" || echo "false")
        log_info "Rate limiting enabled: $RATE_LIMIT_ENABLED"
        log_info "Redis enabled: $ENABLE_REDIS"
    else
        log_warning "api_gateway.json not found, assuming Redis enabled=true"
        ENABLE_REDIS="true"
    fi
    
    # Generate inventory from Terraform outputs
    log_info "Generating inventory file..."
    if [ -f "generate_inventory.sh" ]; then
        ./generate_inventory.sh
    else
        log_error "Script generate_inventory.sh not found"
        exit 1
    fi
    
    log_info "Setting up SSM Agent for Session Manager..."
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventories/hosts playbooks/setup_ssm_agent.yml -e "ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" 2>/dev/null
    
    log_info "Bootstrap PostgreSQL..."
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventories/hosts playbooks/bootstrap_postgresql.yml -e "ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" 2>/dev/null
    
    log_info "Bootstrap Redis..."
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventories/hosts playbooks/bootstrap_redis.yml -e "ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' enable_redis=$ENABLE_REDIS" 2>/dev/null
                
    log_info "Testing all services..."
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventories/hosts playbooks/test_all_services.yml -e "ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" 2>/dev/null
    
    log_success "Servers configured"
    
    cd "$PROJECT_ROOT"
}

# Test plugin registration
register_plugin() {
    log_info "🔌 Test plugin registration in details database"
    
    cd "$PROJECT_ROOT/02-servers-bootstrap"
    
    # Check SSH keys
    if [ ! -f "$PROJECT_ROOT/ssh_keys/stripo-ansible-key" ]; then
        log_error "SSH keys not found. First run Step 1"
        exit 1
    fi
    
    # Set key permissions
    chmod 600 "$PROJECT_ROOT/ssh_keys/stripo-ansible-key"
    chmod 644 "$PROJECT_ROOT/ssh_keys/stripo-ansible-key.pub"
    
    # Generate inventory from Terraform outputs
    log_info "Generating inventory file..."
    if [ -f "generate_inventory.sh" ]; then
        ./generate_inventory.sh
    else
        log_error "Script generate_inventory.sh not found"
        exit 1
    fi
    
    log_info "Registering test plugin..."
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventories/hosts playbooks/register_plugin.yml -e "ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" 2>/dev/null
    
    log_success "Plugin registered"
    
    cd "$PROJECT_ROOT"
}

# Countdown Timer configuration
configure_countdown_timer() {
    log_info "⏰ Countdown Timer configuration"
    
    cd "$PROJECT_ROOT/02-servers-bootstrap"
    
    # Check SSH keys
    if [ ! -f "$PROJECT_ROOT/ssh_keys/stripo-ansible-key" ]; then
        log_error "SSH keys not found. First run Step 1"
        exit 1
    fi
    
    # Set key permissions
    chmod 600 "$PROJECT_ROOT/ssh_keys/stripo-ansible-key"
    chmod 644 "$PROJECT_ROOT/ssh_keys/stripo-ansible-key.pub"
    
    # Generate inventory from Terraform outputs
    log_info "Generating inventory file..."
    if [ -f "generate_inventory.sh" ]; then
        ./generate_inventory.sh
    else
        log_error "Script generate_inventory.sh not found"
        exit 1
    fi
    
    log_info "Countdown Timer configuration (password update + timer_users initialization)..."
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventories/hosts playbooks/configure_countdown_timer.yml -e "ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" 2>/dev/null
    
    log_success "Countdown Timer configured"
    
    cd "$PROJECT_ROOT"
}

# Step 3: Deploy services
deploy_services() {
    log_info "📦 Step 3: ECS services deployment"
    
    # Automatic configuration update from service JSON files
    log_info "🔄 Automatic service configuration update from JSON files..."
    if [ -f "update_services_config.sh" ]; then
        ./update_services_config.sh "$AWS_PROFILE"
        if [ $? -eq 0 ]; then
            log_success "Service configuration updated from JSON files"
        else
            log_error "Error updating service configuration"
            exit 1
        fi
    else
        log_warning "Script update_services_config.sh not found, using existing configuration"
    fi
    
    cd "$PROJECT_ROOT/03-services-deploy"
    
    log_info "Initializing Terraform..."
    terraform init
    
    log_info "Planning changes..."
    terraform plan -var-file=env/dev.tfvars
    
    read -p "Apply changes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Applying changes..."
        terraform apply -var-file=env/dev.tfvars -auto-approve
        log_success "Services deployed"
        
        # If this is part of full deployment, run additional setup steps
        if [ "$MODE" = "full" ]; then
            log_info "🎯 Running additional setup steps for complete demo..."
            
            # Wait for services to be ready
            if monitor_services_progress; then
                log_info "📋 Registering test plugin..."
                register_plugin
                
                log_info "⏰ Configuring countdown timer..."
                configure_countdown_timer
                
                log_success "🎉 Complete demo setup finished!"
            else
                log_warning "Services not ready, skipping additional setup steps"
            fi
        fi
    else
        log_warning "Service deployment skipped"
    fi
    
    cd "$PROJECT_ROOT"
}

# Monitor service startup progress
monitor_services_progress() {
    log_info "📈 Monitoring service startup progress..."
    
    # Set AWS profile and region from dev.tfvars
    AWS_PROFILE=$(grep "^aws_profile" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
    AWS_REGION=$(grep "^aws_region" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
    
    cluster_name=$(cd "$PROJECT_ROOT/01-infrastructure" && terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
    if [ -z "$cluster_name" ]; then
        log_error "ECS Cluster not found"
        return 1
    fi
    
    echo "🏗️  ECS Cluster: $cluster_name"
    echo "⏳ Waiting for services to be ready..."
    echo ""
    
    max_attempts=30
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        services=$(aws ecs list-services --cluster "$cluster_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'serviceArns[]' --output text 2>/dev/null | tr '\n' ' ')
        service_count=$(echo "$services" | wc -w)
        
        if [ $service_count -gt 0 ]; then
            running_count=0
            total_count=0
            
            for service in $services; do
                service_name=$(echo "$service" | sed 's/.*\///')
                service_status=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].runningCount' --output text 2>/dev/null)
                desired_count=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].desiredCount' --output text 2>/dev/null)
                
                if [ "$service_status" = "$desired_count" ] && [ "$service_status" -gt 0 ]; then
                    running_count=$((running_count + 1))
                fi
                total_count=$((total_count + 1))
            done
            
            progress=$((running_count * 100 / total_count))
            echo -ne "\r📊 Progress: $running_count/$total_count services ready ($progress%)"
            
            if [ $running_count -eq $total_count ]; then
                echo ""
                log_success "All services are ready! 🎉"
                
                # Show DNS configuration information
                log_info "🌐 DNS Configuration Information"
                cd "$PROJECT_ROOT/01-infrastructure"
                alb_dns_name=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
                domain_name=$(grep "^domain_name" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
                
                if [ ! -z "$alb_dns_name" ] && [ ! -z "$domain_name" ]; then
                    echo ""
                    echo "🔗 DNS Configuration Required:"
                    echo "================================"
                    echo "📋 Domain: $domain_name"
                    echo "🎯 ALB DNS Name: $alb_dns_name"
                    echo ""
                    echo "⚠️  IMPORTANT: Configure your DNS provider to point:"
                    echo "   $domain_name → $alb_dns_name"
                    echo ""
                    echo "📝 DNS Record Type: CNAME"
                    echo "📝 DNS Record Name: $domain_name"
                    echo "📝 DNS Record Value: $alb_dns_name"
                    echo ""
                    echo "✅ After DNS propagation, your services will be accessible at:"
                    echo "   https://$domain_name"
                fi
                
                cd "$PROJECT_ROOT"
                return 0
            fi
        fi
        
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo ""
    log_warning "Timeout waiting for services to be ready"
    return 1
}

# Check status
check_status() {
    log_info "📊 Checking deployment status"
    
    # Set AWS profile from dev.tfvars
    AWS_PROFILE=$(grep "^aws_profile" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
    
    cd "$PROJECT_ROOT/01-infrastructure"
    
    bastion_ip=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
    postgresql_ip=$(terraform output -raw postgresql_private_ip 2>/dev/null || echo "")
    redis_ip=$(terraform output -raw redis_private_ip 2>/dev/null || echo "")
    
    cd "$PROJECT_ROOT"
    
    # Check server availability
    log_info "🖥️  Checking server availability..."
    echo "🔑 Bastion Host: $bastion_ip"
    echo "🐘 PostgreSQL: $postgresql_ip (internal)"
    echo "🔴 Redis: $redis_ip (internal)"
    echo ""
    
    # Get SSH key path and user from Terraform outputs
    cd "$PROJECT_ROOT/01-infrastructure"
    ssh_key_path="$PROJECT_ROOT/ssh_keys/stripo-ansible-key"
    ssh_user="ubuntu"  # Default user for Ubuntu AMI
    
    cd "$PROJECT_ROOT"
    
    # Check Bastion SSH availability
    if [ ! -z "$bastion_ip" ]; then
        if timeout 5 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$ssh_key_path" $ssh_user@$bastion_ip "echo 'SSH connection successful'" 2>/dev/null; then
            echo "✅ Bastion SSH: available"
        else
            echo "❌ Bastion SSH: unavailable"
        fi
    else
        echo "⚠️  Bastion SSH: IP not found"
    fi
    
    # Check PostgreSQL availability via Bastion
    if [ ! -z "$postgresql_ip" ] && [ ! -z "$bastion_ip" ]; then
        if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$ssh_key_path" $ssh_user@$bastion_ip "nc -z -w5 $postgresql_ip 5432" 2>/dev/null; then
            echo "✅ PostgreSQL: available (port 5432)"
        else
            echo "❌ PostgreSQL: unavailable (port 5432)"
        fi
    else
        echo "⚠️  PostgreSQL: IP not found"
    fi
    
    # Check Redis availability via Bastion
    if [ ! -z "$redis_ip" ] && [ ! -z "$bastion_ip" ]; then
        if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$ssh_key_path" $ssh_user@$bastion_ip "nc -z -w5 $redis_ip 6379" 2>/dev/null; then
            echo "✅ Redis: available (port 6379)"
        else
            echo "❌ Redis: unavailable (port 6379)"
        fi
    else
        echo "⚠️  Redis: IP not found"
    fi
    
    echo ""
    
    # Check ECS services
    log_info "📦 Checking ECS services..."
    if command -v aws &> /dev/null; then
        cluster_name=$(cd "$PROJECT_ROOT/01-infrastructure" && terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
        if [ ! -z "$cluster_name" ]; then
            echo "🏗️  ECS Cluster: $cluster_name"
            
            # Get region from dev.tfvars
            AWS_REGION=$(grep "^aws_region" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
            
            # Debug info removed for production
            
            # Get list of services
            services=$(aws ecs list-services --cluster "$cluster_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'serviceArns[]' --output text 2>/dev/null | tr '\n' ' ')
            service_count=$(echo "$services" | wc -w)
            echo "📊 Number of services: $service_count"
            
            if [ $service_count -gt 0 ]; then
                echo ""
                echo "⏳ Waiting for services to be ready..."
                echo ""
                
                max_attempts=30
                attempt=1
                
                while [ $attempt -le $max_attempts ]; do
                    running_count=0
                    total_count=0
                    all_ready=true
                    
                    # Clear screen to update status
                    echo -ne "\033[2K\r"
                    
                    # Check each service
                    for service_arn in $services; do
                        service_name=$(echo "$service_arn" | sed 's/.*\///')
                        service_status=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].status' --output text 2>/dev/null)
                        running_count_current=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].runningCount' --output text 2>/dev/null)
                        desired_count=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].desiredCount' --output text 2>/dev/null)
                        
                        # Determine status
                        if [ "$service_status" = "ACTIVE" ] && [ "$running_count_current" = "$desired_count" ] && [ "$running_count_current" -gt 0 ]; then
                            status_icon="✅"
                            status_text="OK"
                            running_count=$((running_count + 1))
                        elif [ "$service_status" = "ACTIVE" ]; then
                            status_icon="⚠️"
                            status_text="PARTIAL"
                            all_ready=false
                        else
                            status_icon="❌"
                            status_text="FAILED"
                            all_ready=false
                        fi
                        
                        total_count=$((total_count + 1))
                    done
                    
                    progress=$((running_count * 100 / total_count))
                    echo -ne "\r📊 Progress: $running_count/$total_count services ready ($progress%) - Attempt $attempt/$max_attempts"
                    
                    if [ "$all_ready" = true ]; then
                        echo ""
                        echo ""
                        log_success "All services are ready! 🎉"
                        echo "📋 Status of all services:"
                        echo "=================="
                        
                        # Show final status of all services
                        for service_arn in $services; do
                            service_name=$(echo "$service_arn" | sed 's/.*\///')
                            service_status=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].status' --output text 2>/dev/null)
                            running_count_final=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].runningCount' --output text 2>/dev/null)
                            desired_count=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].desiredCount' --output text 2>/dev/null)
                            
                            if [ "$service_status" = "ACTIVE" ] && [ "$running_count_final" = "$desired_count" ]; then
                                status_icon="✅"
                                status_text="OK"
                            elif [ "$service_status" = "ACTIVE" ]; then
                                status_icon="⚠️"
                                status_text="PARTIAL"
                            else
                                status_icon="❌"
                                status_text="FAILED"
                            fi
                            
                            echo "  $status_icon $service_name ($running_count_final/$desired_count) - $status_text"
                        done
                        break
                    fi
                    
                    if [ $attempt -eq $max_attempts ]; then
                        echo ""
                        echo ""
                        log_warning "Timeout waiting for services to be ready"
                        echo "📋 Final status of services:"
                        echo "=================="
                        
                        # Final check of all services
                        for service_arn in $services; do
                            service_name=$(echo "$service_arn" | sed 's/.*\///')
                            service_status=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].status' --output text 2>/dev/null)
                            running_count_final=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].runningCount' --output text 2>/dev/null)
                            desired_count=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'services[0].desiredCount' --output text 2>/dev/null)
                            
                            if [ "$service_status" = "ACTIVE" ] && [ "$running_count_final" = "$desired_count" ]; then
                                status_icon="✅"
                                status_text="OK"
                            elif [ "$service_status" = "ACTIVE" ]; then
                                status_icon="⚠️"
                                status_text="PARTIAL"
                            else
                                status_icon="❌"
                                status_text="FAILED"
                            fi
                            
                            echo "  $status_icon $service_name ($running_count_final/$desired_count) - $status_text"
                        done
                        break
                    fi
                    
                    sleep 10
                    attempt=$((attempt + 1))
                done
            fi
        else
            echo "🏗️  ECS Cluster: not found"
        fi
    else
        echo "⚠️  AWS CLI not installed, ECS check skipped"
    fi
    
    # Get ALB DNS name and domain for DNS configuration
    log_info "🌐 DNS Configuration Information"
    cd "$PROJECT_ROOT/01-infrastructure"
    alb_dns_name=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    domain_name=$(grep "^domain_name" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
    
    if [ ! -z "$alb_dns_name" ] && [ ! -z "$domain_name" ]; then
        echo ""
        echo "🔗 DNS Configuration Required:"
        echo "================================"
        echo "📋 Domain: $domain_name"
        echo "🎯 ALB DNS Name: $alb_dns_name"
        echo ""
        echo "⚠️  IMPORTANT: Configure your DNS provider to point:"
        echo "   $domain_name → $alb_dns_name"
        echo ""
        echo "📝 DNS Record Type: CNAME"
        echo "📝 DNS Record Name: $domain_name"
        echo "📝 DNS Record Value: $alb_dns_name"
        echo ""
        echo "✅ After DNS propagation, your services will be accessible at:"
        echo "   https://$domain_name"
        
        echo ""
        echo "🎯 Complete Demo Setup Required:"
        echo "================================"
        echo "📋 For full functionality, run these additional steps:"
        echo ""
        echo "1️⃣  Register test plugin:"
        echo "   ./deploy.sh --mode register-plugin"
        echo ""
        echo "2️⃣  Configure Countdown Timer:"
        echo "   ./deploy.sh --mode configure-countdown-timer"
        echo ""
        echo "✅ After completing these steps, the demo will be fully functional!"
    else
        echo ""
        echo "⚠️  DNS information not available"
    fi
    
    cd "$PROJECT_ROOT"
    log_success "Check completed"
}



# Cleanup all resources
cleanup_all() {
    log_warning "🧹 CLEANING UP ALL RESOURCES"
    log_warning "This action is IRREVERSIBLE!"
    echo ""
    
    # Set AWS profile from dev.tfvars
            AWS_PROFILE=$(grep "^aws_profile" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
    
    # Check AWS profile and region
    log_info "🔍 Checking target environment:"
    account_id=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query 'Account' --output text)
    current_region=$(grep "^aws_region" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
    if [ -z "$current_region" ]; then
        current_region="not set"
    fi
    
    echo "  🏢 AWS Account: $account_id"
    echo "  🌍 AWS Region: $current_region"
    echo "  👤 AWS Profile: $AWS_PROFILE"
    echo ""
    
    log_info "Will be deleted:"
    echo "  🏗️  VPC and network (VPC, subnets, Internet Gateway, NAT Gateway)"
    echo "  🖥️  EC2 servers (Bastion, PostgreSQL, Redis)"
    echo "  🔒 Security Groups (all created security groups)"
    echo "  📦 ECS infrastructure (Cluster, ALB, IAM roles, Cloud Map)"
    echo "  🔑 AWS Key Pair (but NOT local SSH keys)"
    echo ""
    log_info "Will NOT be deleted:"
    echo "  📁 Local files (SSH keys in ssh_keys/ will remain)"
    echo "  📄 Terraform state files"
    echo "  ☁️  Other AWS resources (not created by this Terraform)"
    echo ""
    
    read -p "Are you sure? Type 'DELETE' to confirm: " -r
    if [[ $REPLY == "DELETE" ]]; then
        log_info "Updating service configuration..."
        if [ -f "update_services_config.sh" ]; then
            ./update_services_config.sh "$AWS_PROFILE"
        fi
        
        log_info "Deleting services..."
        cd "$PROJECT_ROOT/03-services-deploy"
        if [ -f "terraform.tfstate" ]; then
            terraform destroy -var-file=env/dev.tfvars -auto-approve
        else
            log_info "Services state file not found, skipping"
        fi
        cd "$PROJECT_ROOT"
        
        log_info "Deleting infrastructure..."
        cd "$PROJECT_ROOT/01-infrastructure"
        if [ -f "terraform.tfstate" ]; then
            # Get region from dev.tfvars
            AWS_REGION=$(grep "^aws_region" env/dev.tfvars | cut -d'=' -f2 | tr -d ' "')
            
            # Determine AZs based on region (simply add a and b)
            AZS="[\"${AWS_REGION}a\", \"${AWS_REGION}b\"]"
            
            # Prepare variables for Terraform
            terraform_vars="-var-file=env/dev.tfvars -var=aws_region=$AWS_REGION"
            
            # Create temporary file for AZs
            echo "azs = $AZS" > env/temp_azs.tfvars
            terraform_vars="$terraform_vars -var-file=env/temp_azs.tfvars"
            if [ -n "$SSH_ACCESS_CIDR" ]; then
                terraform_vars="$terraform_vars -var=ssh_access_cidr=$SSH_ACCESS_CIDR"
            fi
            terraform destroy $terraform_vars -auto-approve
        else
            log_info "Infrastructure state file not found, skipping"
        fi
        cd "$PROJECT_ROOT"
        
        log_info "Deleting SSH keys..."
        if [ -d "ssh_keys" ]; then
            rm -rf ssh_keys
            log_info "SSH keys deleted"
        else
            log_info "SSH keys folder not found"
        fi
        
        log_success "All resources deleted"
    else
        log_info "Cleanup cancelled"
    fi
}

# Main function
main() {
    case $MODE in
        "check")
            check_dependencies
            check_aws_profile
            echo ""
            show_checklist
            ;;
        "full")
            # Start timer for full deployment
            start_time=$(date +%s)
            log_info "🚀 Starting full deployment timer..."
            
            # Track time for each phase
            phase1_start=$(date +%s)
            check_dependencies
            check_aws_profile
            phase1_end=$(date +%s)
            phase1_duration=$((phase1_end - phase1_start))
            
            phase2_start=$(date +%s)
            deploy_infrastructure
            phase2_end=$(date +%s)
            phase2_duration=$((phase2_end - phase2_start))
            
            phase3_start=$(date +%s)
            bootstrap_servers
            phase3_end=$(date +%s)
            phase3_duration=$((phase3_end - phase3_start))
            
            phase4_start=$(date +%s)
            deploy_services
            phase4_end=$(date +%s)
            phase4_duration=$((phase4_end - phase4_start))
            
            # Calculate and display deployment time
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            minutes=$((duration / 60))
            seconds=$((duration % 60))
            
            echo ""
            log_success "🎉 Full deployment completed successfully!"
            echo "⏱️  Deployment time breakdown:"
            echo "   📋 Dependencies check: ${phase1_duration}s"
            echo "   🏗️  Infrastructure: ${phase2_duration}s"
            echo "   🔧 Server bootstrap: ${phase3_duration}s"
            echo "   📦 Services deployment: ${phase4_duration}s"
            echo "   ─────────────────────────────"
            echo "   ⏱️  Total time: ${minutes}m ${seconds}s"
            ;;
        "infra")
            check_dependencies
            check_aws_profile
            deploy_infrastructure
            ;;
        "bootstrap-servers")
            bootstrap_servers
            ;;
        "services")
            deploy_services
            ;;
        "register-plugin")
            register_plugin
            ;;
        "configure-countdown-timer")
            configure_countdown_timer
            ;;
        "status")
            check_status
            ;;
        "monitor")
            monitor_services_progress
            ;;
        "cleanup")
            cleanup_all
            ;;
    esac
}

# Run script
parse_arguments "$@"
main 