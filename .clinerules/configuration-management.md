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
- **File**: `cline_mcp_config.env` (example: `cline_mcp_config.example`)
- **Purpose**: Contains sensitive credentials and environment-specific settings
- **Security**: Contains all sensitive data (tokens, passwords, keys)
- **Usage**: NOT version controlled, environment-specific

### 3. Devcontainer Configuration File
- **File**: `.devcontainer/devcontainer-config.env`
- **Purpose**: Contains devcontainer-specific settings for mounting and symlinking
- **Usage**: Used by devcontainer to set up symlinked MCP settings at required paths

## Configuration Structure

The configuration file follows the standard `.env` format where each line contains a key-value pair:

```env
KEY=VALUE
```

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
cp cline_mcp_config.example cline_mcp_config.env

# Edit the file with your actual values
nano cline_mcp_config.env
```

### 2. Load Configuration
```bash
# Load environment variables from config file
export $(grep -v '^#' cline_mcp_config.env | xargs)

# Or use a tool like dotenv to load in your application
```

### 3. File Permissions
```bash
# Set proper permissions for sensitive config file
chmod 600 cline_mcp_config.env
```

## Environment-Specific Configurations

Create different configuration files for different environments:
- `cline_mcp_config.dev.env` - Development environment
- `cline_mcp_config.staging.env` - Staging environment  
- `cline_mcp_config.prod.env` - Production environment

## Devcontainer Setup

The devcontainer is configured to automatically mount and symlink `cline_mcp_settings.json` to two required paths:
1. `~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json`
2. `~/.cline/data/settings/cline_mcp_settings.json`

This is accomplished through the devcontainer configuration in `.devcontainer/` directory.

## Example Usage in Node.js

```javascript
// Load environment variables
require('dotenv').config({ path: 'cline_mcp_config.env' });

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
if [ ! -f "cline_mcp_config.env" ]; then
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

## Integration with Inkorporated Homelab Infrastructure

The configuration values from `cline_mcp_config.env` are automatically loaded into the environment when the MCP servers are started, and are referenced in the `cline_mcp_settings.json` file through environment variable substitution.

This configuration approach is integrated with the Inkorporated homelab's GitOps deployment workflow and follows the project's security patterns including:
- Separation of sensitive credentials from main settings
- Environment-specific configuration management
- Proper file permissions (600) for sensitive files
- Integration with the existing infrastructure as code patterns
- Support for the multi-environment deployment strategy (dev, staging, prod)