#!/bin/bash
set -e

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform not found, skipping validation."
    exit 0
fi

# Locate directories containing .tf files
# We use find to get directories, sort unique, and loop
# This ensures we validate all modules if there are subdirectories
# excluding hidden directories like .terraform
find . -name "*.tf" -not -path "*/.*" -exec dirname {} \; | sort -u | while read -r dir; do
    echo "Validating directory: $dir"
    pushd "$dir" > /dev/null

    # Initialize without backend to just download providers if needed for validation
    # Suppress output to keep logs clean
    terraform init -backend=false > /dev/null

    echo "Running terraform validate in $dir..."
    terraform validate

    popd > /dev/null
done
