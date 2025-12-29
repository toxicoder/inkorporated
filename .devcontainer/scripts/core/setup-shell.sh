#!/bin/bash
# Configure shell environment for MCP

# Update shell initialization files to use existing env-loader.sh
for shell_rc in /home/vscode/.bashrc /home/vscode/.zshrc; do
    if [ -f "$shell_rc" ]; then
        if ! grep -q "env-loader.sh" "$shell_rc"; then
            echo "source /workspaces/inkorporated/.devcontainer/scripts/utilities/env-loader.sh" >> "$shell_rc"
        fi
    else
        echo "source /workspaces/inkorporated/.devcontainer/scripts/utilities/env-loader.sh" >> "$shell_rc"
    fi
done

echo "Shell initialization files configured to source env-loader.sh"