#!/bin/bash
# Main post-create command orchestrator

echo "=== Starting Dev Container Setup ==="
echo "Running as $(whoami)"
echo ""

# Track success/failure
SUCCESS=true

# Run core setup scripts in order
echo "1. Setting up development tools..."
if ! bash /workspaces/inkorporated/.devcontainer/scripts/core/setup-tools.sh; then
    echo "ERROR: Tool setup failed"
    SUCCESS=false
fi

echo ""
echo "2. Setting up MCP configuration..."
if ! bash /workspaces/inkorporated/.devcontainer/scripts/core/setup-mcp.sh; then
    echo "ERROR: MCP setup failed"
    SUCCESS=false
fi

echo ""
echo "3. Configuring shell environment..."
if ! bash /workspaces/inkorporated/.devcontainer/scripts/core/setup-shell.sh; then
    echo "ERROR: Shell setup failed"
    SUCCESS=false
fi

echo ""
echo "4. Handling file operations..."
if ! bash /workspaces/inkorporated/.devcontainer/scripts/core/setup-files.sh; then
    echo "ERROR: File setup failed"
    SUCCESS=false
fi

echo ""
echo "5. Creating .cline directory structure..."
sudo mkdir -p /home/vscode/.cline/data
sudo chown -R vscode:vscode /home/vscode/.cline/

if [ "$SUCCESS" = true ]; then
    echo ""
    echo "=== Dev Container Setup Complete ==="
    echo "All setup scripts completed successfully"
else
    echo ""
    echo "=== Dev Container Setup Completed with Errors ==="
    echo "Some setup scripts failed. Please check the output above."
    exit 1
fi