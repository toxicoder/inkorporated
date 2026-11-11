#!/bin/bash
# Verifies .devcontainer/scripts/utilities/env-loader.sh loads an MCP config
# file into the environment, exports what it loads, and degrades quietly when
# the file is absent.
#
# Run it with: bazelisk test //:test_env_loader
#
# The loader calls load_mcp_env once at source time, before any caller can set
# MCP_CONFIG_FILE, so each case re-invokes the function with the override the
# loader honours. Every case runs in its own bash child so the exported keys
# cannot leak between cases, and nothing here writes into the checkout.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
LOADER="${REPO_ROOT}/.devcontainer/scripts/utilities/env-loader.sh"

if [ ! -f "$LOADER" ]; then
    echo "FAILURE: loader not found at ${LOADER}" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

failures=0
check() {
    local label="$1" status="$2"
    if [ "$status" = "0" ]; then
        echo "ok   - ${label}"
    else
        echo "FAIL - ${label} (exit ${status})" >&2
        failures=$((failures + 1))
    fi
}

# Case 1: a config file with two keys loads them and exports them.
CONFIG_A="${WORKDIR}/mcp-config.env"
cat >"$CONFIG_A" <<'FIXTURE'
TEST_VAR=test_value
ANOTHER_VAR=another_value
FIXTURE

status=0
MCP_CONFIG_FILE="$CONFIG_A" bash -c '
    set -eu
    # shellcheck source=/dev/null
    source "$1"
    load_mcp_env >/dev/null 2>&1
    [ "${TEST_VAR:-}" = "test_value" ] || exit 11
    [ "${ANOTHER_VAR:-}" = "another_value" ] || exit 12
    # set -a around the source is what makes these exported, which is the
    # behaviour the devcontainer shell bootstrap depends on.
    # shellcheck disable=SC2016
    env | grep -q "^ANOTHER_VAR=another_value$" || exit 13
' _ "$LOADER" || status=$?
check "keys from a config file load and export" "$status"

# Case 2: a missing config file is reported and is not fatal.
status=0
out="$(
    MCP_CONFIG_FILE="${WORKDIR}/nope.env" bash -c '
        set -eu
        # shellcheck source=/dev/null
        source "$1"
        load_mcp_env
    ' _ "$LOADER" 2>&1
)" || status=$?
check "a missing config file is not fatal" "$status"
case "$out" in
    *"MCP config file not found"*)
        echo "ok   - a missing config file says so"
        ;;
    *)
        echo "FAIL - a missing config file says so; got: ${out}" >&2
        failures=$((failures + 1))
        ;;
esac

# Case 3: sourcing with no override must not read a real secrets file into the
# test environment; the default path stays the devcontainer secrets file.
if grep -qF 'MCP_CONFIG_FILE="${MCP_CONFIG_FILE:-/workspaces/inkorporated/.devcontainer/.env}"' "$LOADER"; then
    echo "ok   - the default config path stays the devcontainer secrets file"
else
    echo "FAIL - the loader no longer defaults to the devcontainer secrets file" >&2
    failures=$((failures + 1))
fi

# Case 4: the loader is still sourceable under set -u, which is how a shell rc
# file sources it. The config path is pinned to the absent fixture so this case
# never sources a developer's real secrets file.
status=0
MCP_CONFIG_FILE="${WORKDIR}/nope.env" bash -c '
    set -eu
    # shellcheck source=/dev/null
    source "$1"
' _ "$LOADER" >/dev/null || status=$?
check "the loader sources cleanly under set -u" "$status"

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} env-loader assertion(s) failed" >&2
    exit 1
fi

echo "SUCCESS: env-loader loads a config file, exports it, and tolerates its absence"
