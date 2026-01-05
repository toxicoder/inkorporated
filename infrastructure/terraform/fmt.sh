#!/bin/bash
set -e

TERRAFORM_BIN="$1"

if [[ ! -f "$TERRAFORM_BIN" ]]; then
    echo "Terraform binary not found at $TERRAFORM_BIN"
    exit 1
fi

cd infrastructure/terraform

# Check format recursive
"$TERRAFORM_BIN" fmt -check -recursive
