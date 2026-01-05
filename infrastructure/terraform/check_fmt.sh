#!/bin/bash
set -e

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform not found, skipping format check."
    exit 0
fi

echo "Running terraform fmt -check -recursive..."
terraform fmt -check -recursive
