#!/bin/bash
# Test Helm chart validity

echo "Running Helm Chart Tests..."

# Test 1: Check if helm is installed
if command -v helm &> /dev/null; then
    echo "✅ PASS: Helm is installed"
else
    echo "⚠️  INFO: Helm not found (expected if not using Helm charts)"
    exit 0
fi

# Test 2: Check for Helm charts directory
if [ -d "charts" ]; then
    echo "✅ PASS: Charts directory exists"
else
    echo "⚠️  INFO: Charts directory not found (expected in early stages)"
    exit 0
fi

# Test 3: Validate Helm charts (if they exist)
find charts -name "Chart.yaml" | while read chart; do
    chart_dir=$(dirname "$chart")
    chart_name=$(basename "$chart_dir")
    if helm lint "$chart_dir" &> /dev/null; then
        echo "✅ PASS: Helm chart $chart_name is valid"
    else
        echo "❌ FAIL: Helm chart $chart_name has validation errors"
        exit 1
    fi
done

echo "✅ Helm chart tests completed"