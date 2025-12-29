#!/bin/bash
# Simple verification that the ShellCheck fix is in place

echo "Checking if ShellCheck disable directive is present..."

if grep -q "# shellcheck disable=SC1090" .devcontainer/scripts/utilities/env-loader.sh; then
    echo "✓ ShellCheck disable directive found"
    echo "✓ Fix for SC1090 warning is in place"
    echo ""
    echo "The fix addresses the ShellCheck warning:"
    echo "  Line 16: ShellCheck can't follow non-constant source"
    echo ""
    echo "The solution adds a comment directive above the source command:"
    echo "  # shellcheck disable=SC1090"
    echo ""
    echo "This is the standard way to suppress this warning when the"
    echo "source path is dynamically determined at runtime."
    exit 0
else
    echo "✗ ShellCheck disable directive not found"
    exit 1
fi