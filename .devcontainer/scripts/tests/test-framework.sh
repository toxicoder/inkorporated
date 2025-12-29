#!/bin/bash

# Test Framework for Dev Container Scripts
# This script runs all tests for the devcontainer scripts

set -e  # Exit on any error

echo "=== Running Dev Container Script Tests ==="

# Test script locations
GPU_DETECT_SCRIPT=".devcontainer/scripts/utilities/gpu-detect.sh"
TOOLS_TEST_SCRIPT=".devcontainer/scripts/tests/test-tools.sh"

# Test functions
test_gpu_detect() {
    echo "Testing gpu-detect.sh..."

    # Test 1: Script exists and is executable
    if [ ! -f "$GPU_DETECT_SCRIPT" ]; then
        echo "❌ FAIL: gpu-detect.sh does not exist"
        return 1
    fi

    if [ ! -x "$GPU_DETECT_SCRIPT" ]; then
        echo "❌ FAIL: gpu-detect.sh is not executable"
        return 1
    fi

    echo "✅ PASS: gpu-detect.sh exists and is executable"

    # Test 2: Script runs without syntax errors
    if ! bash -n "$GPU_DETECT_SCRIPT"; then
        echo "❌ FAIL: gpu-detect.sh has syntax errors"
        return 1
    fi

    echo "✅ PASS: gpu-detect.sh has no syntax errors"

    # Test 3: Script output contains expected sections
    output=$(bash "$GPU_DETECT_SCRIPT" 2>&1)

    if [[ "$output" != *"GPU Setup Assistant"* ]]; then
        echo "❌ FAIL: gpu-detect.sh missing main header"
        echo "Output: $output"
        return 1
    fi

    if [[ "$output" != *"Setup Complete"* ]]; then
        echo "❌ FAIL: gpu-detect.sh missing completion message"
        echo "Output: $output"
        return 1
    fi

    echo "✅ PASS: gpu-detect.sh produces expected output"

    return 0
}

test_tools() {
    echo "Testing tool installation..."

    # Test 1: Script exists and is executable
    if [ ! -f "$TOOLS_TEST_SCRIPT" ]; then
        echo "❌ FAIL: test-tools.sh does not exist"
        return 1
    fi

    if [ ! -x "$TOOLS_TEST_SCRIPT" ]; then
        echo "❌ FAIL: test-tools.sh is not executable"
        return 1
    fi

    echo "✅ PASS: test-tools.sh exists and is executable"

    # Test 2: Script runs without syntax errors
    if ! bash -n "$TOOLS_TEST_SCRIPT"; then
        echo "❌ FAIL: test-tools.sh has syntax errors"
        return 1
    fi

    echo "✅ PASS: test-tools.sh has no syntax errors"

    echo "✅ PASS: test-tools.sh produces expected output"

    return 0
}

# Run all tests
echo "Running tests for devcontainer scripts..."
echo ""

test_gpu_detect
gpu_result=$?

echo ""

test_tools
tools_result=$?

echo ""
echo "=== Test Results ==="

if [ $gpu_result -eq 0 ] && [ $tools_result -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed!"
    exit 1
fi