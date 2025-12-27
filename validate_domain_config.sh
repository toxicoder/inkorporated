#!/bin/bash

# Validate domain configuration consistency
echo "Validating domain configuration consistency..."

# Check that all Ingress manifests use templated domain references
echo "Checking Ingress manifests for hardcoded domains..."
INGRESS_FILES=$(find apps/shared -name "*Ingress.yaml" -type f)
HARDCODED_COUNT=0

for file in $INGRESS_FILES; do
    if grep -q "example.com" "$file" && ! grep -q "{{ .Env.DOMAIN_BASE }}" "$file"; then
        echo "ERROR: Found hardcoded domain in $file"
        HARDCODED_COUNT=$((HARDCODED_COUNT + 1))
    fi
done

if [ $HARDCODED_COUNT -eq 0 ]; then
    echo "✓ All Ingress manifests use templated domain references"
else
    echo "✗ Found $HARDCODED_COUNT Ingress manifests with hardcoded domains"
    exit 1
fi

# Check that domain-config.yaml has proper structure
echo "Checking domain-config.yaml structure..."
if [ -f "config/domain-config.yaml" ]; then
    if grep -q "base:.*example.com" "config/domain-config.yaml"; then
        echo "✓ domain-config.yaml contains base domain configuration"
    else
        echo "Note: domain-config.yaml may contain environment-specific domains"
    fi
fi

echo "Domain configuration validation completed successfully!"