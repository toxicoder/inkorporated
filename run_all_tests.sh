#!/bin/bash
# Compatibility shim. Bazel is the entry point now: one target runs the whole
# gate. This script exists so that muscle memory, editor tasks, and any external
# automation that still calls it land on the same answer.
#
# Usage:
#   bazelisk run //:run_all_tests
#   bazelisk test //:gate            # the target this script forwards to
set -e

echo "run_all_tests.sh is a shim for the Bazel gate."
echo "Running: bazelisk test //:gate"

if [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
    cd "${BUILD_WORKSPACE_DIRECTORY}"
fi

exec bazelisk test //:gate --test_output=errors
