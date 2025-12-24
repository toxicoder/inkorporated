#!/bin/bash
# Run all tests in the project

echo "=================================="
echo "Running Comprehensive Test Suite"
echo "=================================="

# Set exit on error
set -e

# Make test scripts executable
chmod +x tests/**/*.sh

# Run configuration tests
echo ""
echo "1. Running Configuration Tests..."
./tests/config/test_config_validation.sh
./tests/config/test_env_vars.sh

# Run security tests
echo ""
echo "2. Running Security Tests..."
./tests/security/test_permissions.sh

# Run Kubernetes tests
echo ""
echo "3. Running Kubernetes Tests..."
./tests/kubernetes/test_manifests.sh

# Run integration tests
echo ""
echo "4. Running Integration Tests..."
./tests/integration/test_authentik.sh

echo ""
echo "=================================="
echo "All Tests Completed Successfully!"
echo "=================================="
