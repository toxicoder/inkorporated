#!/bin/bash

# Wrapper script to run ansible-lint on all YAML files
# This script is used by the Bazel BUILD file for Ansible linting

# Set exit on error
set -e

# Check if ansible-lint is installed
if ! command -v ansible-lint &> /dev/null; then
    echo "⚠️  ansible-lint command not found. Skipping linting."
    exit 0
fi

# Run ansible-lint with common options
echo "Running ansible-lint..."
ansible-lint --exclude .git --exclude node_modules --exclude venv "$@"

echo "Ansible linting completed successfully"
