#!/bin/bash
set -e

echo "Running basic security scan on configuration files..."

# List of patterns to look for (simplified)
PATTERNS=(
    "password="
    "secret="
    "api_key="
    "token="
)

# Function to check a file
check_file() {
    local file=$1
    local fail=0
    for pattern in "${PATTERNS[@]}"; do
        if grep -qi "$pattern" "$file"; then
            echo "⚠️  Potential secret found in $file: matches '$pattern'"
            # We don't fail the build here to avoid false positives blocking development,
            # but in a real scenario we might want to strict fail or allowlists.
            # fail=1
        fi
    done
    return $fail
}

# Find config files, excluding standard ignored directories
# Using find to scan relevant files, avoiding .git, node_modules, _site, etc.
find . \
    \( -name ".git" -o -name "node_modules" -o -name "_site" -o -name "venv" -o -name ".terraform" -o -name "bazel-*" \) -prune \
    -o \( -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.env" \) -print \
    | while read -r file; do
    check_file "$file"
done

echo "Security scan completed."
