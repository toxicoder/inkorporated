#!/bin/bash
# validate_config.sh - Validate Cline MCP configuration

echo " validating Cline MCP configuration..."
echo "================================================"

# Check if config file exists
if [ ! -f ".devcontainer/.env" ]; then
    echo "❌ Error: Configuration file '.devcontainer/.env' not found!"
    echo "   Please create it by copying '.devcontainer/.env.example'"
    echo "   and filling in your actual values."
    exit 1
fi

echo "✅ Configuration file found: .devcontainer/.env"

# Check file permissions
if [ -r ".devcontainer/.env" ]; then
    echo "✅ Configuration file is readable"
else
    echo "❌ Error: Configuration file is not readable"
    exit 1
fi

# Check if file has proper permissions (should be 600 or more restrictive)
PERMS=$(stat -c "%a" .devcontainer/.env 2>/dev/null || stat -f "%p" .devcontainer/.env 2>/dev/null | cut -c 4-6)
if [[ $PERMS -le 600 ]]; then
    echo "✅ Configuration file has secure permissions ($PERMS)"
else
    echo "⚠️  Warning: Configuration file permissions ($PERMS) may be too permissive"
    echo "   Consider running: chmod 600 .devcontainer/.env"
fi

# Check for common required variables
REQUIRED_VARS=(
    "GH_TOKEN"
    "PERPLEXITY_API_KEY"
    "TAVILY_API_KEY"
    "MCP_MONGODB_URI"
    "REDIS_PWD"
    "SLACK_MCP_XOXC_TOKEN"
)

echo ""
echo "Checking for required configuration variables..."
for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^$var=" .devcontainer/.env 2>/dev/null; then
        # Check if variable is set (not empty)
        VALUE=$(grep "^$var=" .devcontainer/.env | cut -d'=' -f2-)
        if [ -n "$VALUE" ] && [ "$VALUE" != "your_${var,,}_here" ] && [ "$VALUE" != "YOUR_${var}_HERE" ]; then
            echo "✅ $var is configured"
        else
            echo "⚠️  $var appears to be a placeholder - please update it"
        fi
    else
        echo "⚠️  $var is not set in configuration file"
    fi
done

echo ""
echo "================================================"
echo "Configuration validation complete!"
echo ""
echo "Next steps:"
echo "1. Make sure all sensitive values are properly set"
echo "2. Set secure file permissions: chmod 600 .devcontainer/.env"
echo "3. Load configuration: export \$(grep -v '^#' .devcontainer/.env | xargs)"