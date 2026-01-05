#!/bin/bash
set -e

echo "Checking for required tools..."

if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Please install it."
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "Terraform not found. Please install it."
    exit 1
fi

if ! command -v ansible &> /dev/null; then
    echo "Ansible not found. Please install it."
    exit 1
fi

echo "All tools found."
echo "Initializing Hybrid Environment..."

# Place holder for state migration or initial setup logic
if [ -f "infrastructure/terraform/terraform.tfstate" ]; then
    echo "Existing Terraform state found."
    echo "Migration logic is handled by 'moved' blocks in infrastructure/terraform/main.tf."
    echo "Please run the following commands to verify migration:"
    echo "  cd infrastructure/terraform"
    echo "  terraform init"
    echo "  terraform plan"
else
    echo "No existing Terraform state found."
fi

echo "Initialization complete."
