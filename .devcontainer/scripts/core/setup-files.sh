#!/bin/bash
# Handle file operations and package.json creation

# Create package.json if it doesn't exist
if [ ! -f "/workspaces/inkorporated/package.json" ]; then
    cat > /workspaces/inkorporated/package.json << 'EOF'
{
  "name": "inkorporated",
  "version": "1.0.0",
  "description": "Inkorporated Homelab Infrastructure",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1",
    "start": "echo \"Starting Inkorporated infrastructure\""
  },
  "keywords": [
    "homelab",
    "infrastructure",
    "kubernetes",
    "gitops",
    "devops"
  ],
  "author": "Inkorporated Team",
  "license": "MIT"
}
EOF
fi

# Install npm dependencies
cd /workspaces/inkorporated && npm install

# Copy MCP settings file
mkdir -p /home/vscode/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/
cp -f /workspaces/inkorporated/.devcontainer/cline_mcp_settings.json \
    /home/vscode/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json

# Set permissions for sensitive files
MCP_CONFIG_FILE="/home/vscode/.config/cline/mcp/cline_mcp_config.env"
if [ -f "/workspaces/inkorporated/.devcontainer/cline_mcp_config.env" ]; then
    mkdir -p "$(dirname "$MCP_CONFIG_FILE")"
    cp -f "/workspaces/inkorporated/.devcontainer/cline_mcp_config.env" "$MCP_CONFIG_FILE"
    chmod 600 "$MCP_CONFIG_FILE"
fi