#!/bin/bash
# Test script to verify MCP environment variable loading

echo "Testing MCP environment variable loading..."

# Check if the loader script exists
if [ -f "/home/vscode/.devcontainer/load-mcp-env.sh" ]; then
    echo "✓ MCP environment loader script exists"
    
    # Source the loader script to test it
    set -a
    source "/home/vscode/.devcontainer/load-mcp-env.sh"
    set +a
    
    echo "✓ MCP environment loader script executed successfully"
    
    # Check if environment variables are loaded (this would be done by the actual config file)
    if [ -f "/home/vscode/.config/cline/mcp/cline_mcp_config.env" ]; then
        echo "✓ MCP config file exists"
        echo "MCP config file contents:"
        cat "/home/vscode/.config/cline/mcp/cline_mcp_config.env"
    else
        echo "ℹ MCP config file not found (expected in clean environment)"
    fi
else
    echo "✗ MCP environment loader script not found"
    exit 1
fi

echo "Environment loading test completed."