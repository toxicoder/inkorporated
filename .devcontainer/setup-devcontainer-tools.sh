#!/bin/bash
# Setup additional dev container tools

echo "Installing additional tools for file management..."
sudo apt-get update
sudo apt-get install -y coreutils findutils

echo "Adding vscode user to appropriate groups..."
sudo usermod -aG vscode $(whoami)

echo "Installing Node.js linting and formatting tools..."
# Install common linting and formatting tools globally
npm install -g eslint prettier cline

echo "Installing Python linting and formatting tools..."
# Install Python tools for linting and formatting
pip install black flake8 yapf

echo "Installing YAML linting tools..."
# Install YAML linting tools
sudo apt-get install -y yamllint

echo "Installing other language formatting tools..."
# Install clang-format for C/C++ (if needed)
sudo apt-get install -y clang-format

echo "Installing Argo CD..."
arch=$(uname -m)
if [ "$arch" = "x86_64" ]; then
    echo "Downloading Argo CD for x86_64..."
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
    echo "Downloading Argo CD for ARM64..."
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-arm64
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

echo "Moving Argo CD to /usr/local/bin..."
sudo mv /tmp/argocd /usr/local/bin/argocd

echo "Setting execute permissions..."
sudo chmod +x /usr/local/bin/argocd

echo "Argo CD installation complete."

# Check for local config directory and use it if available
echo "Checking for local MCP config directory..."
LOCAL_MCP_CONFIG_DIR="$HOME/Code/devcontainers/config/env"
if [ -d "$LOCAL_MCP_CONFIG_DIR" ]; then
    echo "Found local MCP config directory: $LOCAL_MCP_CONFIG_DIR"
    
    # Check for cline_mcp_config.env
    if [ -f "$LOCAL_MCP_CONFIG_DIR/cline_mcp_config.env" ]; then
        echo "Using cline_mcp_config.env from local config directory"
        cp -f "$LOCAL_MCP_CONFIG_DIR/cline_mcp_config.env" /workspaces/inkorporated/.devcontainer/cline_mcp_config.env
    fi
fi

# Check for MacOS-specific config directory and use it if available
echo "Checking for MacOS-specific config directory..."
MACOS_CONFIG_DIR="$HOME/Code/config/vscode/env"
if [ -d "$MACOS_CONFIG_DIR" ]; then
    echo "Found MacOS config directory: $MACOS_CONFIG_DIR"
    
    # Check for devcontainer-config.env
    if [ -f "$MACOS_CONFIG_DIR/devcontainer-config.env" ]; then
        echo "Using devcontainer-config.env from MacOS config directory"
        cp -f "$MACOS_CONFIG_DIR/devcontainer-config.env" /workspaces/inkorporated/.devcontainer/devcontainer-config.env
    fi
    
    # Check for cline_mcp_config.env
    if [ -f "$MACOS_CONFIG_DIR/cline_mcp_config.env" ]; then
        echo "Using cline_mcp_config.env from MacOS config directory"
        cp -f "$MACOS_CONFIG_DIR/cline_mcp_config.env" /workspaces/inkorporated/.devcontainer/cline_mcp_config.env
    fi
fi

# Ensure the MCP config environment file exists and has proper permissions
echo "Ensuring MCP config environment file exists with proper permissions..."
MCP_CONFIG_FILE="/home/vscode/.config/cline/mcp/cline_mcp_config.env"
if [ -f "/workspaces/inkorporated/.devcontainer/cline_mcp_config.env" ]; then
    # Copy the config file to the proper location
    mkdir -p "$(dirname "$MCP_CONFIG_FILE")"
    cp -f "/workspaces/inkorporated/.devcontainer/cline_mcp_config.env" "$MCP_CONFIG_FILE"
    chmod 600 "$MCP_CONFIG_FILE"
    echo "MCP config file copied to $MCP_CONFIG_FILE with 600 permissions"
fi

echo "Copying Cline MCP settings file..."
mkdir -p /home/vscode/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/
cp -f /workspaces/inkorporated/.devcontainer/cline_mcp_settings.json /home/vscode/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json