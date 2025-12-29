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