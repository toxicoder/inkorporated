#!/bin/bash
# Compatibility shim. Bazel is the entry point now: one target runs the whole
# gate. This script exists so that muscle memory, editor tasks, and any external
# automation that still calls it land on the same answer.
#
# Usage: call this script directly, or use the target it forwards to:
#   bazelisk test //:gate            # the one command that answers the question
set -e

echo "run_all_tests.sh is a shim for the Bazel gate."
echo "Running: bazelisk test //:gate"

if [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
    cd "${BUILD_WORKSPACE_DIRECTORY}"
fi

exec bazelisk test //:gate --test_output=errors
