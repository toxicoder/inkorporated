#!/bin/bash

# Wrapper script to run ansible-lint on all YAML files
# This script is used by the Bazel BUILD file for Ansible linting

# Set exit on error
set -e

# Run ansible-lint with common options
ansible-lint --exclude .git --exclude node_modules --exclude venv "$@"

echo "Ansible linting completed successfully"