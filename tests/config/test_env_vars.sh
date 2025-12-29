#!/bin/bash
# Test environment variable loading and validation

echo "Running Environment Variable Tests..."

# Test loading configuration
if export $(grep -v '^#' .devcontainer/.env | xargs) 2>/dev/null; then
    echo "✅ PASS: Configuration loaded successfully"
else
    echo "❌ FAIL: Failed to load configuration"
    exit 1
fi

# Test specific variables are loaded
if [ -n "$GH_TOKEN" ] && [ "$GH_TOKEN" != "your_github_personal_access_token_here" ]; then
    echo "✅ PASS: GitHub token loaded correctly"
else
    echo "⚠️  WARN: GitHub token may not be properly configured"
fi

echo "✅ Environment variable tests completed"