#!/bin/bash
# Test file permissions for security

echo "Running Security Permission Tests..."

# Test configuration file permissions
if [ -f "cline_mcp_config.env" ]; then
    PERMS=$(stat -c "%a" cline_mcp_config.env 2>/dev/null || stat -f "%p" cline_mcp_config.env 2>/dev/null | cut -c 4-6)
    if [[ $PERMS -le 600 ]]; then
        echo "✅ PASS: Configuration file permissions secure ($PERMS)"
    else
        echo "❌ FAIL: Configuration file permissions too permissive ($PERMS)"
        exit 1
    fi
else
    echo "❌ FAIL: Configuration file not found"
    exit 1
fi

# Test example config file permissions (should be readable)
if [ -f "cline_mcp_config.example" ]; then
    PERMS=$(stat -c "%a" cline_mcp_config.example 2>/dev/null || stat -f "%p" cline_mcp_config.example 2>/dev/null | cut -c 4-6)
    if [[ $PERMS -ge 644 ]]; then
        echo "✅ PASS: Example configuration file permissions correct ($PERMS)"
    else
        echo "❌ FAIL: Example configuration file permissions incorrect ($PERMS)"
        exit 1
    fi
else
    echo "❌ FAIL: Example configuration file not found"
    exit 1
fi

echo "✅ Security permission tests completed"
