# Cline MCP Configuration Management

## Overview
This document describes the configuration management approach for Cline MCP servers. The configuration system separates sensitive credentials from the main settings file to improve security and maintainability.

## Configuration Files

### 1. Main Settings File
- **File**: `cline_mcp_settings.json`
- **Purpose**: Contains server configurations and settings
- **Security**: Does NOT contain sensitive credentials
- **Usage**: Version controlled, shared across environments

### 2. Configuration File
- **File**: `.devcontainer/.env`
- **Purpose**: Contains sensitive credentials and environment-specific settings
- **Security**: Contains all sensitive data (tokens, passwords, keys)
- **Usage**: NOT version controlled, environment-specific

### 3. Devcontainer Configuration File
- **File**: `.devcontainer/devcontainer-config.env`
- **Purpose**: Contains devcontainer-specific settings for mounting and symlinking (MCP configuration variables are in .devcontainer/.env)
- **Usage**: Used by devcontainer to set up symlinked MCP settings at required paths

## Configuration Structure

The configuration file follows the standard `.env` format where each line contains a key-value pair:

```env
KEY=VALUE
```

## MCP Server Configuration

MCP servers are now controlled via environment variables rather than JSON configuration:
- All MCP servers are disabled by default via the `MCP_SERVERS_DISABLED=true` environment variable
- To enable MCP servers, set `MCP_SERVERS_DISABLED=false` in your environment configuration
- This provides centralized control over MCP server activation/deactivation
- The previous `disabled: true` flag has been removed from the JSON configuration file

## Security Best Practices

1. **Never commit sensitive data** to version control
2. **Create a separate .env file** for each environment
3. **Use environment variables** to load configuration at runtime
4. **Implement proper file permissions** (600) for config files
5. **Regularly rotate credentials** for production systems

## Usage Instructions

### 1. Setup Configuration
```bash
# Copy the example configuration file
cp .devcontainer/.env.example .devcontainer/.env

# Edit the file with your actual values
nano .devcontainer/.env
```

### 2. Load Configuration
```bash
# Load environment variables from config file
export $(grep -v '^#' .devcontainer/.env | xargs)

# Or use a tool like dotenv to load in your application
```

### 3. File Permissions
```bash
# Set proper permissions for sensitive config file
chmod 600 .devcontainer/.env
```

## Environment-Specific Configurations

Create different configuration files for different environments:

- `.devcontainer/.env.dev` - Development environment
- `.devcontainer/.env.staging` - Staging environment
- `.devcontainer/.env.prod` - Production environment

## Devcontainer Setup

The devcontainer is configured to automatically mount and symlink `cline_mcp_settings.json` to two required paths:
1. `~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json`
2. `~/.cline/data/settings/cline_mcp_settings.json`

This is accomplished through the devcontainer configuration in `.devcontainer/` directory.

## Example Usage in Node.js

```javascript
// Load environment variables
require('dotenv').config({ path: '.devcontainer/.env' });

// Access configuration values
const githubToken = process.env.GH_TOKEN;
const mongoUri = process.env.MCP_MONGODB_URI;
```

## Validation Script

A simple validation script can be created to verify configuration:

```bash
#!/bin/bash
# validate_config.sh

echo "Validating configuration..."
if [ ! -f ".devcontainer/.env" ]; then
    echo "Error: Configuration file not found!"
    exit 1
fi

# Check for required environment variables
REQUIRED_VARS=("GH_TOKEN" "PERPLEXITY_API_KEY" "TAVILY_API_KEY" "OLLAMA_API_BASE_URL" "OPEN_WEBUI_API_BASE_URL" "VECTOR_SEARCH_EMBEDDING_MODEL")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "$var" ]; then
        echo "Warning: Required variable $var not set"
    fi
done

echo "Configuration validation complete."
```

## Integration with MCP Servers

The configuration values from `.devcontainer/.env` are automatically loaded into the environment when the MCP servers are started. The `cline_mcp_settings.json` file references these environment variables through variable substitution (e.g., `${GH_TOKEN}`). The devcontainer setup ensures that both `.devcontainer/.env` and `cline_mcp_settings.json` are properly available within the development environment.