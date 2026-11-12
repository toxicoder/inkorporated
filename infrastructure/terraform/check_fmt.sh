#!/bin/bash
set -e

# Check if terraform is installed
if ! command -v terraform >/dev/null 2>&1; then
    if [ "${REQUIRE_LINT_TOOLS:-0}" = "1" ] || [ "${CI:-}" = "true" ] || [ "${CI:-}" = "1" ]; then
        echo "error: terraform not found but REQUIRE_LINT_TOOLS/CI is set; install it or run //:doctor" >&2
        exit 1
    fi
    echo "WARN: terraform not found, skipping (set REQUIRE_LINT_TOOLS=1 to make this fatal)"
    exit 0
fi

echo "Running terraform fmt -check -recursive..."
terraform fmt -check -recursive
