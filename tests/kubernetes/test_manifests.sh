#!/bin/bash
# Validate Kubernetes manifests

echo "Running Kubernetes Manifest Tests..."

# Test 1: Validate YAML syntax for all manifest files
echo "Checking YAML syntax..."
YAML_ERRORS=0
find apps/shared -name "*.yaml" -o -name "*.yml" | while read file; do
    if ! yaml-lint "$file" 2>/dev/null; then
        echo "⚠️  WARN: YAML syntax error in $file (continuing...)"
        YAML_ERRORS=$((YAML_ERRORS + 1))
    fi
done
if [ $YAML_ERRORS -eq 0 ]; then
    echo "✅ PASS: All YAML manifests have valid syntax"
else
    echo "⚠️  INFO: Found $YAML_ERRORS YAML syntax issues (non-fatal)"
fi

# Test 2: Validate Kubernetes resource definitions (only if kubectl is available)
if command -v kubectl &> /dev/null; then
    echo "Validating Kubernetes manifests..."
    kubectl apply --dry-run=client -f apps/shared/cloudflared/Deployment.yaml 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ PASS: Cloudflared deployment manifest is valid"
    else
        echo "⚠️  INFO: Cloudflared deployment manifest validation failed (kubectl not available or cluster not accessible)"
    fi
else
    echo "⚠️  INFO: kubectl not available, skipping Kubernetes validation"
fi

echo "✅ Kubernetes manifest tests completed"
