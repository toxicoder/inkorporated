# Cline MCP Configuration System

## Overview
This project provides a secure configuration management system for Cline MCP servers. The configuration system separates sensitive credentials from the main settings file to improve security and maintainability.

## Files

### Main Configuration Files
- `cline_mcp_settings.json` - Main MCP server settings (contains no sensitive data)
- `cline_mcp_config.example` - Example configuration with placeholder values
- `cline_mcp_config.env` - Actual configuration file (not version controlled)

### Management Scripts
- `validate_config.sh` - Script to validate configuration setup

## Security Approach

The configuration system follows security best practices:
1. **Separation of Concerns**: Sensitive credentials are separated from settings
2. **Version Control Safety**: No sensitive data is committed to version control
3. **File Permissions**: Config files are secured with restrictive permissions
4. **Environment Variables**: Configuration loaded at runtime

## Setup Instructions

### 1. Create Configuration File
```bash
# Copy the example configuration file
cp cline_mcp_config.example cline_mcp_config.env

# Edit the file with your actual values
nano cline_mcp_config.env
```

### 2. Set Secure Permissions
```bash
# Set restrictive permissions on config file
chmod 600 cline_mcp_config.env
```

### 3. Load Configuration
```bash
# Load environment variables
export $(grep -v '^#' cline_mcp_config.env | xargs)

# Or use a dotenv library in your application
```

### 4. Validate Setup
```bash
# Run validation script
./validate_config.sh
```

## Configuration Structure

The configuration file follows the standard `.env` format:
```env
# GitHub Token
GH_TOKEN=your_actual_github_token_here

# Perplexity API Key
PERPLEXITY_API_KEY=your_perplexity_api_key_here

# Tavily API Key
TAVILY_API_KEY=your_tavily_api_key_here

# MongoDB URI
MCP_MONGODB_URI=mongodb://your_mongo_uri_here

# Redis Password
REDIS_PWD=your_redis_password_here

# Slack Token
SLACK_MCP_XOXC_TOKEN=your_slack_token_here
```

## Environment-Specific Configurations

Create different configuration files for different environments:
- `cline_mcp_config.dev.env` - Development environment
- `cline_mcp_config.staging.env` - Staging environment  
- `cline_mcp_config.prod.env` - Production environment

## Security Best Practices

1. **Never commit sensitive data** to version control
2. **Use environment variables** to load configuration at runtime
3. **Set proper file permissions** (600) for config files
4. **Regularly rotate credentials** for production systems
5. **Use different configurations** for different environments

## Integration with MCP Servers

The configuration values from `cline_mcp_config.env` are automatically loaded into the environment when the MCP servers are started, and are referenced in the `cline_mcp_settings.json` file through environment variable substitution.

## Documentation

For detailed configuration management information, see:
- `config_management.md` - Comprehensive configuration management guide
