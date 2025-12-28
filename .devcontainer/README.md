# Devcontainer Configuration

This directory contains the configuration for the generalized developer container that provides a consistent development environment for this project.

## MCP Settings Configuration

The `.devcontainer/cline_mcp_settings.json` file is automatically mounted and made available at two locations within the dev container:

1. `~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json`
2. `~/.cline/data/settings/cline_mcp_settings.json`

This is accomplished through symlinks created during container initialization.

## Configuration Files

### `devcontainer-config.env`
Contains environment variables that control the devcontainer setup:
- `SETTINGS_FILE_PATH`: Path to the source settings file
- `TARGET_PATH_1` and `TARGET_PATH_2`: Target symlink locations
- `CREATE_SYMLINKS`: Toggle for symlink creation (default: true)
- Devcontainer-specific configuration settings only

### `cline_mcp_config.env.example`
Example configuration file containing all MCP server environment variables.
Copy this file to `cline_mcp_config.env` and populate with your actual values.

### `cline_mcp_settings.json`
The main MCP server settings file containing configurations for various services.

## Environment Variable Management

All environment variables used in the MCP settings can be overridden through:
1. The `cline_mcp_config.env` file (for sensitive data)
2. Environment variables set in the devcontainer
3. Default values provided in `devcontainer-config.env`

## MacOS-Specific Configuration

On MacOS, the devcontainer will automatically check for configuration files in `~/Code/config/vscode/env` directory:
- If `devcontainer-config.env` exists there, it will be used instead of the default file
- If `cline_mcp_config.env` exists there, it will be used instead of the default file

This allows for per-machine configuration while keeping the default files in version control.

## Mounting and Symlinking

The devcontainer is configured to:
1. Mount the source settings file via bind mount
2. Create symlinks during container initialization
3. Make the settings available at both required paths

## Usage

To use this configuration:
1. Ensure `cline_mcp_config.env` exists with your actual values
2. The devcontainer will automatically set up the symlinks
3. Both target paths will point to the same source file

## Customization

To customize the behavior:
1. Modify `devcontainer-config.env` to change paths or disable symlinks
2. Update `cline_mcp_settings.json` with your MCP server configurations
3. Set appropriate environment variables in `cline_mcp_config.env`