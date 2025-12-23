#!/bin/bash

# Test Framework for Dev Container Scripts
# This script runs all tests for the devcontainer scripts

set -e  # Exit on any error

echo "=== Running Dev Container Script Tests ==="

# Test script locations
GPU_SETUP_SCRIPT=".devcontainer/gpu-setup.sh"
POST_CREATE_SCRIPT=".devcontainer/test-post-create.sh"

# Test functions
test_gpu_setup() {
    echo "Testing gpu-setup.sh..."
    
    # Test 1: Script exists and is executable
    if [ ! -f "$GPU_SETUP_SCRIPT" ]; then
        echo "❌ FAIL: gpu-setup.sh does not exist"
        return 1
    fi
    
    if [ ! -x "$GPU_SETUP_SCRIPT" ]; then
        echo "❌ FAIL: gpu-setup.sh is not executable"
        return 1
    fi
    
    echo "✅ PASS: gpu-setup.sh exists and is executable"
    
    # Test 2: Script runs without syntax errors
    if ! bash -n "$GPU_SETUP_SCRIPT"; then
        echo "❌ FAIL: gpu-setup.sh has syntax errors"
        return 1
    fi
    
    echo "✅ PASS: gpu-setup.sh has no syntax errors"
    
    # Test 3: Script output contains expected sections
    output=$(bash "$GPU_SETUP_SCRIPT" 2>&1)
    
    if [[ "$output" != *"Dev Container GPU Setup Assistant"* ]]; then
        echo "❌ FAIL: gpu-setup.sh missing main header"
        echo "Output: $output"
        return 1
    fi
    
    if [[ "$output" != *"Setup Complete"* ]]; then
        echo "❌ FAIL: gpu-setup.sh missing completion message"
        echo "Output: $output"
        return 1
    fi
    
    echo "✅ PASS: gpu-setup.sh produces expected output"
    
    return 0
}

test_post_create() {
    echo "Testing test-post-create.sh..."
    
    # Test 1: Script exists and is executable
    if [ ! -f "$POST_CREATE_SCRIPT" ]; then
        echo "❌ FAIL: test-post-create.sh does not exist"
        return 1
    fi
    
    if [ ! -x "$POST_CREATE_SCRIPT" ]; then
        echo "❌ FAIL: test-post-create.sh is not executable"
        return 1
    fi
    
    echo "✅ PASS: test-post-create.sh exists and is executable"
    
    # Test 2: Script runs without syntax errors
    if ! bash -n "$POST_CREATE_SCRIPT"; then
        echo "❌ FAIL: test-post-create.sh has syntax errors"
        return 1
    fi
    
    echo "✅ PASS: test-post-create.sh has no syntax errors"
    
    # Test 3: Script output contains expected sections
    output=$(bash "$POST_CREATE_SCRIPT" 2>&1)
    
    if [[ "$output" != *"Testing post-create commands..."* ]]; then
        echo "❌ FAIL: test-post-create.sh missing test header"
        echo "Output: $output"
        return 1
    fi
    
    if [[ "$output" != *"Test completed successfully!"* ]]; then
        echo "❌ FAIL: test-post-create.sh missing completion message"
        echo "Output: $output"
        return 1
    fi
    
    echo "✅ PASS: test-post-create.sh produces expected output"
    
    return 0
}

# Run all tests
echo "Running tests for devcontainer scripts..."
echo ""

test_gpu_setup
gpu_result=$?

echo ""

test_post_create
post_create_result=$?

echo ""
echo "=== Test Results ==="

if [ $gpu_result -eq 0 ] && [ $post_create_result -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed!"
    exit 1
fi
