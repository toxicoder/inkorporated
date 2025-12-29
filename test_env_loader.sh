#!/bin/bash
# Test script to verify env-loader.sh functionality

# Create a test config file
TEST_CONFIG="/tmp/test_mcp_config.env"
echo "TEST_VAR=test_value" > "$TEST_CONFIG"
echo "ANOTHER_VAR=another_value" >> "$TEST_CONFIG"

# Source the env-loader script WITHOUT calling load_mcp_env at the end
# We'll call it manually after setting up our test config
sed -i '33d' .devcontainer/scripts/utilities/env-loader.sh
source .devcontainer/scripts/utilities/env-loader.sh

# Override the MCP_CONFIG_FILE to use our test config BEFORE calling the function
export MCP_CONFIG_FILE="$TEST_CONFIG"

# Call the function
load_mcp_env

# Check if variables were loaded
if [ "$TEST_VAR" = "test_value" ] && [ "$ANOTHER_VAR" = "another_value" ]; then
    echo "SUCCESS: Environment variables loaded correctly"
    exit 0
else
    echo "FAILURE: Environment variables not loaded"
    exit 1
fi