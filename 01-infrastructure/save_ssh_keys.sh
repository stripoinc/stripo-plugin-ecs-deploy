#!/bin/bash

# Script for saving SSH keys after creating Terraform infrastructure

set -e

# Determine project root directory (works from any subdirectory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔑 Checking SSH keys..."

# Check if new keys were generated
if terraform output -raw public_key_openssh > /dev/null 2>&1; then
    # Check if keys differ from existing ones
    EXISTING_KEY=""
    if [ -f "$PROJECT_ROOT/ssh_keys/stripo-ansible-key.pub" ]; then
        EXISTING_KEY=$(cat "$PROJECT_ROOT/ssh_keys/stripo-ansible-key.pub")
    fi
    
    NEW_KEY=$(terraform output -raw public_key_openssh)
    
    if [ "$EXISTING_KEY" != "$NEW_KEY" ]; then
        echo "🆕 New SSH keys detected, saving..."
        
        # Create directory for keys if it doesn't exist
mkdir -p "$PROJECT_ROOT/ssh_keys"

# Save private key
echo "📝 Saving private key..."
terraform output -raw private_key_pem > "$PROJECT_ROOT/ssh_keys/stripo-ansible-key"

# Save public key
echo "📝 Saving public key..."
terraform output -raw public_key_openssh > "$PROJECT_ROOT/ssh_keys/stripo-ansible-key.pub"

# Set correct permissions
chmod 600 "$PROJECT_ROOT/ssh_keys/stripo-ansible-key"
chmod 644 "$PROJECT_ROOT/ssh_keys/stripo-ansible-key.pub"

echo "✅ New SSH keys saved in $PROJECT_ROOT/ssh_keys/"
        echo "🔐 Private key: stripo-ansible-key"
        echo "🔓 Public key: stripo-ansible-key.pub"
        echo "📋 Permissions set (600 for private, 644 for public)"
    else
        echo "✅ Existing SSH keys are up to date, nothing changed"
    fi
else
    echo "ℹ️  SSH keys were not generated (using existing ones)"
fi 