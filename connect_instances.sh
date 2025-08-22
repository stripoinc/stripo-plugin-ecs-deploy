#!/bin/bash

# Script for connecting to EC2 instances via AWS Systems Manager Session Manager (SSM)
# Usage: ./connect_instances.sh [bastion|postgresql|redis]

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
get_aws_profile() {
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
        
        # Get env_prefix for instance name formation
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

# Get instance ID by name
get_instance_id() {
    local instance_name="$1"
    local instance_id
    
    instance_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" \
        --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' \
        --output text)
    
    if [ -z "$instance_id" ]; then
        log_error "Instance $instance_name not found or not running"
        exit 1
    fi
    
    echo "$instance_id"
}

# Connect to instance via Session Manager
connect_to_instance() {
    local instance_name="$1"
    local instance_id
    
    log_info "Searching for instance $instance_name..."
    instance_id=$(get_instance_id "$instance_name")
    log_success "Found instance: $instance_id"
    
    log_info "Connecting to $instance_name via Session Manager..."
    log_warning "To exit session use: exit"
    
    aws ssm start-session --target "$instance_id"
}

# Main logic
main() {
    local server_type="$1"
    
    check_aws_cli
    get_aws_profile
    
    case "$server_type" in
        "bastion")
            connect_to_instance "${ENV_PREFIX}-bastion"
            ;;
        "postgresql")
            connect_to_instance "${ENV_PREFIX}-postgresql"
            ;;
        "redis")
            connect_to_instance "${ENV_PREFIX}-redis"
            ;;
        "list"|"ls")
            log_info "Available servers:"
            echo "  bastion    - Bastion host (public)"
            echo "  postgresql - PostgreSQL server (private)"
            echo "  redis      - Redis server (private)"
            echo ""
            echo "Usage: $0 [bastion|postgresql|redis]"
            ;;
        *)
            log_error "Unknown server type: $server_type"
            echo ""
            echo "Available options:"
            echo "  bastion    - Connect to Bastion host"
            echo "  postgresql - Connect to PostgreSQL server"
            echo "  redis      - Connect to Redis server"
            echo "  list       - Show list of available servers"
            echo ""
            echo "Example: $0 bastion"
            exit 1
            ;;
    esac
}

# Run script
if [ $# -eq 0 ]; then
    log_error "Server type not specified"
    echo ""
    echo "Usage: $0 [bastion|postgresql|redis|list]"
    echo ""
    echo "Examples:"
    echo "  $0 bastion     - Connect to Bastion host"
    echo "  $0 postgresql  - Connect to PostgreSQL server"
    echo "  $0 redis       - Connect to Redis server"
    echo "  $0 list        - Show list of servers"
    exit 1
fi

main "$1"
