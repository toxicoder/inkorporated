#!/bin/bash
# Regression check for the ShellCheck status of the devcontainer shell helpers.
#
# env-loader.sh sources a path chosen at runtime, which ShellCheck cannot
# follow, so the file carries a `# shellcheck disable=SC1090` directive above
# that source. If the directive is ever dropped the lint lane goes red, and if
# the helpers pick up a new warning this check goes red with it.
#
# Run it with: bazelisk test //:verify_fix

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
UTILITIES_DIR="${REPO_ROOT}/.devcontainer/scripts/utilities"
LOADER="${UTILITIES_DIR}/env-loader.sh"

if [ ! -f "$LOADER" ]; then
    echo "Error: loader not found at ${LOADER}" >&2
    exit 1
fi

if ! command -v shellcheck >/dev/null 2>&1; then
    if [ "${REQUIRE_LINT_TOOLS:-0}" = "1" ] || [ "${CI:-}" = "1" ] || [ "${CI:-}" = "true" ]; then
        echo "Error: shellcheck is required for this lane. Install it with:" >&2
        echo "  apt-get install -y shellcheck" >&2
        exit 1
    fi
    echo "Warning: shellcheck missing, only the SC1090 directive is verified."
    if grep -q '# shellcheck disable=SC1090' "$LOADER"; then
        echo "OK: the SC1090 directive is present in env-loader.sh"
        exit 0
    fi
    echo "Error: the SC1090 directive is missing from ${LOADER}" >&2
    exit 1
fi

# The directive itself: without it the dynamic source is reported as SC1090.
if ! grep -q '# shellcheck disable=SC1090' "$LOADER"; then
    echo "Error: env-loader.sh sources a runtime path but no longer carries" >&2
    echo "       '# shellcheck disable=SC1090' above that source." >&2
    exit 1
fi

status=0
shellcheck --severity=warning "${LOADER}" "${UTILITIES_DIR}/gpu-detect.sh" || status=$?
if [ "$status" -ne 0 ]; then
    echo "Error: shellcheck reported problems in ${UTILITIES_DIR} (exit ${status})." >&2
    echo "       Fix the findings; do not widen the disable directives." >&2
    exit "$status"
fi

echo "OK: env-loader.sh keeps its SC1090 directive and both helpers are shellcheck-clean"
