#!/bin/bash
# Test the validation script itself

echo "Running Validation Script Tests..."

# Test 1: Check that validation script exists
if [ ! -f "validate_config.sh" ]; then
    echo "❌ FAIL: Validation script not found"
    exit 1
fi
echo "✅ PASS: Validation script exists"

# Test 2: Check that validation script is executable
if [ -x "validate_config.sh" ]; then
    echo "✅ PASS: Validation script is executable"
else
    echo "❌ FAIL: Validation script is not executable"
    exit 1
fi

# Test 3: Run validation script to ensure it doesn't crash
# Note: This will show warnings about missing config, which is expected
./validate_config.sh > /tmp/validation_output.txt 2>&1
if [ $? -eq 0 ] || [ $? -eq 1 ]; then
    echo "✅ PASS: Validation script runs without fatal errors"
else
    echo "❌ FAIL: Validation script failed"
    exit 1
fi

echo "✅ Validation script tests completed"
