#!/bin/bash
# Validate configuration files and environment variables

echo "Running Configuration Validation Tests..."

# Test 1: Check config file exists
if [ ! -f "cline_mcp_config.env" ]; then
    echo "❌ FAIL: Configuration file not found"
    exit 1
fi
echo "✅ PASS: Configuration file exists"

# Test 2: Check file permissions
PERMS=$(stat -c "%a" cline_mcp_config.env 2>/dev/null || stat -f "%p" cline_mcp_config.env 2>/dev/null | cut -c 4-6)
if [[ $PERMS -le 600 ]]; then
    echo "✅ PASS: Configuration file has secure permissions ($PERMS)"
else
    echo "❌ FAIL: Configuration file permissions ($PERMS) may be too permissive"
    exit 1
fi

# Test 3: Check required environment variables
REQUIRED_VARS=(
    "GH_TOKEN"
    "PERPLEXITY_API_KEY"
    "TAVILY_API_KEY"
    "MCP_MONGODB_URI"
    "REDIS_PWD"
    "SLACK_MCP_XOXC_TOKEN"
)

for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^$var=" cline_mcp_config.env 2>/dev/null; then
        VALUE=$(grep "^$var=" cline_mcp_config.env | cut -d'=' -f2-)
        if [ -n "$VALUE" ] && [ "$VALUE" != "your_${var,,}_here" ] && [ "$VALUE" != "YOUR_${var}_HERE" ]; then
            echo "✅ PASS: $var is configured"
        else
            echo "⚠️  WARN: $var appears to be a placeholder"
        fi
    else
        echo "❌ FAIL: $var is not set in configuration file"
        exit 1
    fi
done

echo "✅ All configuration validation tests passed"
