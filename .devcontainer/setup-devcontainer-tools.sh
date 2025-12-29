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

# Ensure package.json exists for npm operations
echo "Ensuring package.json exists for npm operations..."
if [ ! -f "/workspaces/inkorporated/package.json" ]; then
    echo "Creating package.json for npm operations..."
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
    echo "package.json created successfully"
fi

# Install npm dependencies
echo "Installing npm dependencies..."
cd /workspaces/inkorporated && npm install

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
    
    # Check for .env.example (now in devcontainer directory)
    if [ -f "$LOCAL_MCP_CONFIG_DIR/.env.example" ]; then
        echo "Using .env.example from local config directory"
        cp -f "$LOCAL_MCP_CONFIG_DIR/.env.example" /workspaces/inkorporated/.devcontainer/.env.example
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
    
    # Check for .env.example (now in devcontainer directory)
    if [ -f "$MACOS_CONFIG_DIR/.env.example" ]; then
        echo "Using .env.example from MacOS config directory"
        cp -f "$MACOS_CONFIG_DIR/.env.example" /workspaces/inkorporated/.devcontainer/.env.example
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

# Create shell initialization scripts for MCP environment loading
echo "Creating shell initialization scripts for MCP environment loading..."

# Create the MCP environment loader script
cat > /home/vscode/.devcontainer/load-mcp-env.sh << 'EOF'
#!/bin/bash
# Load MCP environment variables early in container lifecycle
# This script should be sourced in shell initialization files

# Function to load MCP environment variables
load_mcp_env() {
    # Path to the MCP config file
    MCP_CONFIG_FILE="/home/vscode/.config/cline/mcp/cline_mcp_config.env"
    
    # Check if the config file exists
    if [ -f "$MCP_CONFIG_FILE" ]; then
        echo "Loading MCP environment variables from $MCP_CONFIG_FILE"
        # Source the environment file to load variables into current shell
        # Set -a to automatically export all variables, then source, then unset -a
        set -a  # Automatically export all variables
        if source "$MCP_CONFIG_FILE"; then
            set +a  # Stop automatic export
            echo "MCP environment variables loaded successfully"
        else
            set +a  # Stop automatic export even if source fails
            echo "Warning: Failed to load MCP environment variables from $MCP_CONFIG_FILE"
        fi
    else
        echo "MCP config file not found: $MCP_CONFIG_FILE"
        echo "This is expected if using default or alternative config setup"
    fi
}

# Load MCP environment variables
load_mcp_env
EOF

# Make the loader script executable
chmod +x /home/vscode/.devcontainer/load-mcp-env.sh

# Ensure bash initialization includes MCP loader
if [ -f "/home/vscode/.bashrc" ]; then
    if ! grep -q "load-mcp-env.sh" "/home/vscode/.bashrc"; then
        echo "source /home/vscode/.devcontainer/load-mcp-env.sh" >> /home/vscode/.bashrc
        echo "Added MCP environment loader to .bashrc"
    fi
else
    echo "source /home/vscode/.devcontainer/load-mcp-env.sh" > /home/vscode/.bashrc
    echo "Created .bashrc with MCP environment loader"
fi

# Ensure zsh initialization includes MCP loader
if [ -f "/home/vscode/.zshrc" ]; then
    if ! grep -q "load-mcp-env.sh" "/home/vscode/.zshrc"; then
        echo "source /home/vscode/.devcontainer/load-mcp-env.sh" >> /home/vscode/.zshrc
        echo "Added MCP environment loader to .zshrc"
    fi
else
    echo "source /home/vscode/.devcontainer/load-mcp-env.sh" > /home/vscode/.zshrc
    echo "Created .zshrc with MCP environment loader"
fi

echo "Shell initialization scripts created successfully"