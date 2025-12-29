#!/bin/bash
# Setup MCP configuration files and permissions

# Check for local config directories
LOCAL_MCP_CONFIG_DIR="$HOME/Code/devcontainers/config/env"
MACOS_CONFIG_DIR="$HOME/Code/config/vscode/env"

# Copy MCP config files from local directories
if [ -d "$LOCAL_MCP_CONFIG_DIR" ]; then
    echo "Found local MCP config directory: $LOCAL_MCP_CONFIG_DIR"
    [ -f "$LOCAL_MCP_CONFIG_DIR/cline_mcp_config.env" ] && \
        cp -f "$LOCAL_MCP_CONFIG_DIR/cline_mcp_config.env" /workspaces/inkorporated/.devcontainer/cline_mcp_config.env
fi

# Check for MacOS config directory
if [ -d "$MACOS_CONFIG_DIR" ]; then
    echo "Found MacOS config directory: $MACOS_CONFIG_DIR"
    [ -f "$MACOS_CONFIG_DIR/devcontainer-config.env" ] && \
        cp -f "$MACOS_CONFIG_DIR/devcontainer-config.env" /workspaces/inkorporated/.devcontainer/devcontainer-config.env
fi