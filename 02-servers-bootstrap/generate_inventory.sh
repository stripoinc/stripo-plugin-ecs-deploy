#!/bin/bash

# Script for generating inventory from Terraform outputs

set -e

# Determine project root directory (works from any subdirectory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check dependencies
if ! command -v jq &> /dev/null; then
    log_error "jq is not installed"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    log_error "terraform is not installed"
    exit 1
fi

# Go to infrastructure directory
cd "$PROJECT_ROOT/01-infrastructure"

# Get outputs from Terraform
log_info "Getting server information from Terraform..."

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    log_error "Terraform state not found. First run infrastructure creation."
    exit 1
fi

# Get outputs in JSON format
terraform_output=$(terraform output -json)

# Extract IP addresses
bastion_public_ip=$(echo "$terraform_output" | jq -r '.bastion_public_ip.value')
bastion_private_ip=$(echo "$terraform_output" | jq -r '.bastion_private_ip.value')
postgresql_private_ip=$(echo "$terraform_output" | jq -r '.postgresql_private_ip.value')
redis_private_ip=$(echo "$terraform_output" | jq -r '.redis_private_ip.value')

# Check if Redis is enabled
enable_redis=$(echo "$terraform_output" | jq -r '.redis_private_ip.value != null and .redis_private_ip.value != ""')


# Check if IP addresses were obtained
if [ -z "$bastion_public_ip" ] || [ "$bastion_public_ip" = "null" ]; then
    log_error "Failed to get Bastion server public IP"
    exit 1
fi

log_success "Server IP addresses obtained:"
echo "  🏰 Bastion: $bastion_public_ip (public)"
echo "  🐘 PostgreSQL: $postgresql_private_ip"
if [ "$enable_redis" = "true" ]; then
    echo "  🔴 Redis: $redis_private_ip"
else
    echo "  🔴 Redis: disabled"
fi


# Create inventory file
cd "$PROJECT_ROOT/02-servers-bootstrap"

log_info "Creating inventory file..."

# Create base inventory file
if [ "$enable_redis" = "true" ]; then
    # Create inventory with Redis
    cat > inventories/hosts << EOF
# Ansible inventory file
# Generated automatically from Terraform outputs

[bastion]
bastion-server ansible_host=$bastion_public_ip ansible_user=ubuntu ansible_ssh_private_key_file=../ssh_keys/stripo-ansible-key

[postgresql]
postgresql-server ansible_host=$postgresql_private_ip ansible_user=ubuntu ansible_ssh_private_key_file=../ssh_keys/stripo-ansible-key

[redis]
redis-server ansible_host=$redis_private_ip ansible_user=ubuntu ansible_ssh_private_key_file=../ssh_keys/stripo-ansible-key

[servers:children]
postgresql
redis
EOF
else
    # Create inventory without Redis
    cat > inventories/hosts << EOF
# Ansible inventory file
# Generated automatically from Terraform outputs

[bastion]
bastion-server ansible_host=$bastion_public_ip ansible_user=ubuntu ansible_ssh_private_key_file=../ssh_keys/stripo-ansible-key

[postgresql]
postgresql-server ansible_host=$postgresql_private_ip ansible_user=ubuntu ansible_ssh_private_key_file=../ssh_keys/stripo-ansible-key

[servers:children]
postgresql
EOF
fi

# Add connection settings
cat >> inventories/hosts << EOF

# Settings for connection through Bastion
[servers:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q -i ../ssh_keys/stripo-ansible-key ubuntu@$bastion_public_ip"'
ansible_ssh_extra_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

log_success "Inventory file created: inventories/hosts"

# Show content for verification
log_info "Inventory file content:"
echo ""
cat inventories/hosts
echo ""

log_success "Inventory ready for use with Ansible!" 