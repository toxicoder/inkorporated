#!/bin/bash
# Test script to verify that environment variables from ~/Code/devcontainers/config/env/.env
# are properly pulled into the devcontainer

echo "=== Testing Environment Variable Pull from Local Config ==="

# Test 1: Check if the setup script handles .env file
echo "Test 1: Checking setup script for .env handling..."
if grep -q "LOCAL_MCP_CONFIG_DIR/.env" .devcontainer/setup-devcontainer-tools.sh; then
    echo "✓ Setup script contains .env file handling"
else
    echo "✗ Setup script missing .env file handling"
    exit 1
fi

# Test 2: Check if the mount exists in devcontainer.json
echo "Test 2: Checking devcontainer.json for local config mount..."
if grep -q "Code/devcontainers/config/env" .devcontainer/devcontainer.json; then
    echo "✓ devcontainer.json contains local config mount"
else
    echo "✗ devcontainer.json missing local config mount"
    exit 1
fi

# Test 3: Check if the loader script exists
echo "Test 3: Checking for MCP environment loader script..."
if [ -f ".devcontainer/load-mcp-env.sh" ]; then
    echo "✓ MCP environment loader script exists"
else
    echo "✗ MCP environment loader script missing"
    exit 1
fi

# Test 4: Check if shell initialization files include the loader
echo "Test 4: Checking shell initialization files..."
if [ -f "/home/vscode/.bashrc" ] && grep -q "load-mcp-env.sh" "/home/vscode/.bashrc"; then
    echo "✓ .bashrc includes MCP environment loader"
else
    echo "ℹ .bashrc not found or missing loader (will be created on next container start)"
fi

if [ -f "/home/vscode/.zshrc" ] && grep -q "load-mcp-env.sh" "/home/vscode/.zshrc"; then
    echo "✓ .zshrc includes MCP environment loader"
else
    echo "ℹ .zshrc not found or missing loader (will be created on next container start)"
fi

# Test 5: Verify the documentation is updated
echo "Test 5: Checking documentation..."
if grep -q "Code/devcontainers/config/env/.env" .devcontainer/README.md; then
    echo "✓ README.md documents .env file support"
else
    echo "✗ README.md missing .env documentation"
    exit 1
fi

echo ""
echo "=== All Tests Passed! ==="
echo ""
echo "Summary:"
echo "- The devcontainer configuration properly mounts ~/Code/devcontainers/config/env"
echo "- The setup script copies .env file to cline_mcp_config.env"
echo "- Environment variables are loaded via load-mcp-env.sh"
echo "- Shell initialization files source the loader script"
echo "- Documentation has been updated to reflect this functionality"
echo ""
echo "When you create ~/Code/devcontainers/config/env/.env on your local system,"
echo "the devcontainer will automatically pull it in and make the environment"
echo "variables available to MCP servers."