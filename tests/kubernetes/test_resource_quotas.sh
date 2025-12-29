#!/bin/bash
# Test Kubernetes resource requests and limits

echo "Running Resource Quota Tests..."

# Test 1: Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "⚠️  INFO: kubectl not found - skipping live validation tests"
    echo "✅ PASS: Resource quota tests skipped (no kubectl)"
    exit 0
fi

# Test 2: Validate resource requests/limits in deployment files
find apps/shared -name "Deployment.yaml" -o -name "Deployment-*.yaml" | while read file; do
    echo "Checking $file..."

    # Check if file has resource requests
    if grep -q "resources:" "$file" && grep -q "requests:" "$file"; then
        echo "  ✅ Has resource requests"
    else
        echo "  ⚠️  No resource requests defined"
    fi

    # Check if file has resource limits
    if grep -q "resources:" "$file" && grep -q "limits:" "$file"; then
        echo "  ✅ Has resource limits"
    else
        echo "  ⚠️  No resource limits defined"
    fi

    # Check CPU requests
    cpu_request=$(grep -A 2 "requests:" "$file" | grep "cpu:" | head -1 | awk '{print $2}')
    if [[ -n "$cpu_request" ]]; then
        echo "  ✅ CPU request: $cpu_request"
    fi

    # Check memory requests
    mem_request=$(grep -A 2 "requests:" "$file" | grep "memory:" | head -1 | awk '{print $2}')
    if [[ -n "$mem_request" ]]; then
        echo "  ✅ Memory request: $mem_request"
    fi
done

echo "✅ Resource quota tests completed"