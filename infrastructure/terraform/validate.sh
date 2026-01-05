#!/bin/bash
set -e

TERRAFORM_BIN="$1"
# Bazel runfiles handling
if [[ ! -f "$TERRAFORM_BIN" ]]; then
    echo "Terraform binary not found at $TERRAFORM_BIN"
    exit 1
fi

# Go to the directory containing the .tf files
# In Bazel, this is usually the package root.
# infrastructure/terraform
cd infrastructure/terraform

# Initialize without backend (we just want to validate)
"$TERRAFORM_BIN" init -backend=false

# Validate
"$TERRAFORM_BIN" validate
