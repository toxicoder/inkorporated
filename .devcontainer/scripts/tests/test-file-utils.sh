#!/bin/bash
# Test script to verify file deletion functionality in the devcontainer

echo "Testing file deletion capabilities..."

# Create a test file in the workspace (where user has permissions)
echo "This is a test file for deletion" > ./test-delete-file.txt

# Verify file exists
if [ -f ./test-delete-file.txt ]; then
    echo "✓ Test file created successfully"
else
    echo "✗ Failed to create test file"
    exit 1
fi

# Test basic file deletion
rm -f ./test-delete-file.txt

# Verify file was deleted
if [ ! -f ./test-delete-file.txt ]; then
    echo "✓ File deletion test passed"
else
    echo "✗ File deletion test failed"
    exit 1
fi

# Test recursive deletion
mkdir -p ./test-dir
echo "test content" > ./test-dir/test-file.txt
rm -rf ./test-dir

if [ ! -d ./test-dir ]; then
    echo "✓ Recursive deletion test passed"
else
    echo "✗ Recursive deletion test failed"
    exit 1
fi

# Test find and delete functionality
mkdir -p ./find-test
echo "test content 1" > ./find-test/file1.txt
echo "test content 2" > ./find-test/file2.txt
find ./find-test -name "*.txt" -delete

if [ ! -f ./find-test/file1.txt ] && [ ! -f ./find-test/file2.txt ]; then
    echo "✓ Find and delete test passed"
else
    echo "✗ Find and delete test failed"
    exit 1
fi

echo "All file deletion tests passed successfully!"
