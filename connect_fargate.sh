#!/bin/bash

# Script for connecting to ECS Fargate containers via AWS ECS Exec
# Usage: ./connect_fargate.sh <service-name>

set -e

# Determine project root path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check AWS CLI
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
}

# Get AWS profile and region from dev.tfvars
get_aws_config() {
    if [ -f "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" ]; then
        AWS_PROFILE=$(grep "^aws_profile" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
        if [ -z "$AWS_PROFILE" ]; then
            log_error "aws_profile not found in $PROJECT_ROOT/01-infrastructure/env/dev.tfvars"
            exit 1
        fi
        export AWS_PROFILE="$AWS_PROFILE"
        
        # Get region from profile
        AWS_REGION=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || echo "us-east-1")
        export AWS_REGION="$AWS_REGION"
        
        # Get env_prefix for name formation
        ENV_PREFIX=$(grep "^env_prefix" "$PROJECT_ROOT/01-infrastructure/env/dev.tfvars" | cut -d'=' -f2 | tr -d ' "')
        if [ -z "$ENV_PREFIX" ]; then
            log_error "env_prefix not found in $PROJECT_ROOT/01-infrastructure/env/dev.tfvars"
            exit 1
        fi
        
        log_info "Using AWS profile: $AWS_PROFILE"
        log_info "Using AWS region: $AWS_REGION"
        log_info "Using env_prefix: $ENV_PREFIX"
    else
        log_error "File $PROJECT_ROOT/01-infrastructure/env/dev.tfvars not found"
        exit 1
    fi
}

# Get list of services
get_services() {
    local cluster_name="${ENV_PREFIX}-ecs-cluster"
    
    log_info "Getting list of services from cluster $cluster_name..."
    
    services=$(aws ecs list-services \
        --cluster "$cluster_name" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --query 'serviceArns[]' \
        --output text 2>/dev/null | tr '\n' ' ')
    
    if [ -z "$services" ]; then
        log_error "Services not found in cluster $cluster_name"
        exit 1
    fi
    
    echo "$services"
}

# Get task ARN for service
get_task_arn() {
    local service_name="$1"
    local cluster_name="${ENV_PREFIX}-ecs-cluster"
    
    task_arn=$(aws ecs list-tasks \
        --cluster "$cluster_name" \
        --service-name "$service_name" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --query 'taskArns[0]' \
        --output text 2>/dev/null)
    
    if [ "$task_arn" = "None" ] || [ -z "$task_arn" ]; then
        log_error "Task not found for service $service_name"
        exit 1
    fi
    
    echo "$task_arn"
}

# Connect to container via ECS Exec
connect_to_container() {
    local service_name="$1"
    local cluster_name="${ENV_PREFIX}-ecs-cluster"
    local task_arn
    
    log_info "Searching for task for service $service_name..."
    task_arn=$(get_task_arn "$service_name")
    log_success "Found task: $task_arn"
    
    log_info "Connecting to container $service_name via ECS Exec..."
    log_warning "To exit session use: exit"
    
    
    aws ecs execute-command \
        --cluster "$cluster_name" \
        --task "$task_arn" \
        --container "$service_name" \
        --command "/bin/sh" \
        --interactive \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE"
}

# Main logic
main() {
    local service_name="$1"
    
    check_aws_cli
    get_aws_config
    
    if [ "$service_name" = "list" ] || [ "$service_name" = "ls" ]; then
        log_info "Available services:"
        services=$(get_services)
        
        for service in $services; do
            service_short=$(echo "$service" | sed 's/.*\///')
            echo "  $service_short"
        done
        echo ""
        echo "Usage: $0 <service-name>"
        echo "Example: $0 stripo-plugin-api-gateway"
        exit 0
    fi
    
    if [ -z "$service_name" ]; then
        log_error "Service name not specified"
        echo ""
        echo "Usage: $0 <service-name>"
        echo "Example: $0 stripo-plugin-api-gateway"
        echo ""
        echo "To view list of services: $0 list"
        exit 1
    fi
    
    # Check if service exists
    services=$(get_services)
    service_found=false
    
    for service in $services; do
        service_short=$(echo "$service" | sed 's/.*\///')
        if [ "$service_short" = "$service_name" ]; then
            service_found=true
            break
        fi
    done
    
    if [ "$service_found" = false ]; then
        log_error "Service $service_name not found"
        echo ""
        echo "Available services:"
        for service in $services; do
            service_short=$(echo "$service" | sed 's/.*\///')
            echo "  $service_short"
        done
        exit 1
    fi
    
    connect_to_container "$service_name"
}

# Run script
if [ $# -eq 0 ]; then
    log_error "Service name not specified"
    echo ""
    echo "Usage: $0 <service-name>"
    echo "Example: $0 stripo-plugin-api-gateway"
    echo ""
    echo "To view list of services: $0 list"
    exit 1
fi

main "$1"
