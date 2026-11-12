#!/bin/bash
# Asserts the devcontainer environment wiring: the MCP env loader loads and
# exports what it is pointed at, the operator env template still declares every
# key the MCP catalogue interpolates, the shell bootstrap wires the loader into
# both rc files exactly once, the container mounts the local env directory
# read-only, and the secrets file stays out of git.
#
# Run it with: bazelisk test //.devcontainer/scripts/tests:test_env
#
# The loader is driven through its MCP_CONFIG_FILE override so no case here can
# read a developer's real secrets file, and every write lands in mktemp.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../../.." && pwd)"
DEVCONTAINER="${REPO_ROOT}/.devcontainer"
LOADER="${DEVCONTAINER}/scripts/utilities/env-loader.sh"
ENV_TEMPLATE="${DEVCONTAINER}/.env.example"
CONFIG_TEMPLATE="${DEVCONTAINER}/devcontainer-config.env.example"
SETUP_SHELL="${DEVCONTAINER}/scripts/core/setup-shell.sh"
DEVCONTAINER_JSON="${DEVCONTAINER}/devcontainer.json"
README="${DEVCONTAINER}/README.md"
TARGET="bazelisk test //.devcontainer/scripts/tests:test_env"

for required in "$LOADER" "$ENV_TEMPLATE" "$CONFIG_TEMPLATE" "$SETUP_SHELL" \
    "$DEVCONTAINER_JSON" "$README"; do
    if [ ! -f "$required" ]; then
        echo "FAIL - expected file is missing: ${required}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    fi
done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

BASH_PATH="$(command -v bash)"
failures=0

# Gate lane: these two are always present, so a missing one is a broken host
# and must stop the lane with the command that puts it back.
require_tool() {
    local tool="$1" install="$2"
    command -v "$tool" >/dev/null 2>&1 || {
        echo "FAIL - ${tool} is required by this lane; install it with: ${install}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    }
}

require_tool jq "apt-get install -y jq"
require_tool git "apt-get install -y git"

check() {
    local label="$1" status="$2"
    if [ "$status" = "0" ]; then
        echo "ok   - ${label}"
    else
        echo "FAIL - ${label} (exit ${status})" >&2
        echo "       re-run with: ${TARGET}" >&2
        failures=$((failures + 1))
    fi
}

expect_text() {
    local label="$1" needle="$2" file="$3"
    if grep -qF -- "$needle" "$file"; then
        echo "ok   - ${label}"
    else
        echo "FAIL - ${label}; expected to find: ${needle}" >&2
        echo "       in ${file}" >&2
        echo "       re-run with: ${TARGET}" >&2
        failures=$((failures + 1))
    fi
}

# awk rather than grep -c: grep exits 1 on a zero count, which a strict shell
# would read as the test itself failing.
count_lines_with() {
    local needle="$1" file="$2"
    awk -v needle="$needle" 'index($0, needle) > 0 { found++ } END { print found + 0 }' "$file"
}

# ---------------------------------------------------------------------------
# 1. The loader exports what it loads, and tolerates its file being absent.
# ---------------------------------------------------------------------------
CONFIG_FIXTURE="${WORKDIR}/mcp.env"
cat >"$CONFIG_FIXTURE" <<'FIXTURE'
MCP_TEST_LOADED=loaded
MCP_TEST_OTHER=other
FIXTURE

status=0
MCP_CONFIG_FILE="$CONFIG_FIXTURE" "$BASH_PATH" -c '
    set -eu
    # shellcheck source=/dev/null
    source "$1"
    load_mcp_env >/dev/null 2>&1
    [ "${MCP_TEST_LOADED:-}" = "loaded" ] || exit 11
    [ "${MCP_TEST_OTHER:-}" = "other" ] || exit 12
    # set -a around the source is what exports the keys, which is how the MCP
    # servers started by the editor see them.
    [ "${MCP_TEST_OTHER:-}" = "$(env | sed -n "s/^MCP_TEST_OTHER=//p")" ] || exit 13
' _ "$LOADER" || status=$?
check "keys from an env file load and are exported" "$status"

status=0
absent_out="$(
    MCP_CONFIG_FILE="${WORKDIR}/absent.env" "$BASH_PATH" -c '
        set -eu
        # shellcheck source=/dev/null
        source "$1"
        load_mcp_env
    ' _ "$LOADER" 2>&1
)" || status=$?
check "a missing env file is not fatal under set -e" "$status"
case "$absent_out" in
    *"not found"*)
        echo "ok   - a missing env file says so instead of failing silently"
        ;;
    *)
        echo "FAIL - a missing env file should be reported; got: ${absent_out}" >&2
        echo "       re-run with: ${TARGET}" >&2
        failures=$((failures + 1))
        ;;
esac

# The default path must stay the gitignored secrets file, so a shell that
# sources the loader without an override can never pick up a fixture.
expect_text "the loader defaults to the devcontainer secrets file" \
    'MCP_CONFIG_FILE="${MCP_CONFIG_FILE:-/workspaces/inkorporated/.devcontainer/.env}"' \
    "$LOADER"

if git -C "$REPO_ROOT" ls-files --error-unmatch .devcontainer/.env >/dev/null 2>&1; then
    echo "FAIL - .devcontainer/.env is tracked by git; secrets must never be committed" >&2
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
else
    echo "ok   - .devcontainer/.env is not tracked by git"
fi

if git -C "$REPO_ROOT" check-ignore -q .devcontainer/.env; then
    echo "ok   - .devcontainer/.env is gitignored"
else
    echo "FAIL - .devcontainer/.env is not gitignored; add it to .gitignore" >&2
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
fi

# ---------------------------------------------------------------------------
# 2. The env template still declares every key the container is documented to
#    need, in KEY="value" shape, with placeholders rather than credentials.
# ---------------------------------------------------------------------------
REQUIRED_KEYS=(
    GH_TOKEN
    PERPLEXITY_API_KEY
    TAVILY_API_KEY
    MCP_MONGODB_URI
    REDIS_PWD
    SLACK_MCP_XOXC_TOKEN
    OLLAMA_API_BASE_URL
    OPEN_WEBUI_API_BASE_URL
    VECTOR_SEARCH_EMBEDDING_MODEL
    DOMAIN_BASE
)
missing_keys=""
for key in "${REQUIRED_KEYS[@]}"; do
    if ! grep -qE "^[[:space:]]*(export[[:space:]]+)?${key}=" "$ENV_TEMPLATE"; then
        missing_keys="${missing_keys} ${key}"
    fi
done
if [ -z "$missing_keys" ]; then
    echo "ok   - .env.example declares all ${#REQUIRED_KEYS[@]} required keys"
else
    echo "FAIL - .env.example is missing:${missing_keys}" >&2
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
fi

bad_template_lines="$(
    awk '
        /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
        /^[A-Za-z_][A-Za-z0-9_]*=/ { next }
        { bad++ }
        END { print bad + 0 }
    ' "$ENV_TEMPLATE"
)"
if [ "$bad_template_lines" = "0" ]; then
    echo "ok   - every .env.example line is a comment or a KEY=assignment"
else
    echo "FAIL - ${bad_template_lines} line(s) in .env.example are not KEY=VALUE" >&2
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
fi

if grep -qE 'gh[pousr]_|xox[baprs]-|sk-[A-Za-z0-9]|AKIA[0-9A-Z]{16}|[A-Za-z0-9+/]{32,}' \
    "$ENV_TEMPLATE"; then
    echo "FAIL - .env.example contains something that is not a placeholder" >&2
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
else
    echo "ok   - .env.example carries placeholders only, no credential shapes"
fi

expect_text "devcontainer-config.env.example documents the settings path" \
    "SETTINGS_FILE_PATH=" "$CONFIG_TEMPLATE"

# ---------------------------------------------------------------------------
# 3. The shell bootstrap wires the loader into both rc files, once each, and
#    creates them when they do not exist. Run against a temp copy so the
#    container home stays out of it.
# ---------------------------------------------------------------------------
FAKE_HOME="${WORKDIR}/home"
mkdir -p "$FAKE_HOME"
SETUP_SHELL_COPY="${WORKDIR}/setup-shell.sh"
sed "s|/home/vscode|${FAKE_HOME}|g" "$SETUP_SHELL" >"$SETUP_SHELL_COPY"

status=0
"$BASH_PATH" "$SETUP_SHELL_COPY" >/dev/null || status=$?
check "the shell bootstrap runs from an empty home" "$status"

for rc in .bashrc .zshrc; do
    rc_file="${FAKE_HOME}/${rc}"
    if [ ! -f "$rc_file" ]; then
        echo "FAIL - the shell bootstrap did not create ${rc}" >&2
        echo "       re-run with: ${TARGET}" >&2
        failures=$((failures + 1))
        continue
    fi
    lines="$(count_lines_with "env-loader.sh" "$rc_file")"
    if [ "$lines" = "1" ] && grep -qF "scripts/utilities/env-loader.sh" "$rc_file"; then
        echo "ok   - ${rc} sources env-loader.sh exactly once"
    else
        echo "FAIL - ${rc} sources env-loader.sh ${lines} time(s)" >&2
        echo "       re-run with: ${TARGET}" >&2
        failures=$((failures + 1))
    fi
done

status=0
"$BASH_PATH" "$SETUP_SHELL_COPY" >/dev/null || status=$?
check "the shell bootstrap is idempotent" "$status"
for rc in .bashrc .zshrc; do
    lines="$(count_lines_with "env-loader.sh" "${FAKE_HOME}/${rc}")"
    if [ "$lines" = "1" ]; then
        echo "ok   - ${rc} still sources the loader once after a second run"
    else
        echo "FAIL - ${rc} now sources the loader ${lines} time(s); the guard regressed" >&2
        echo "       re-run with: ${TARGET}" >&2
        failures=$((failures + 1))
    fi
done

# ---------------------------------------------------------------------------
# 4. The container mounts the operator env directory read-only at the path the
#    loader documents.
# ---------------------------------------------------------------------------
if ! jq -e . "$DEVCONTAINER_JSON" >/dev/null 2>&1; then
    echo "FAIL - devcontainer.json is not valid JSON" >&2
    echo "       the devcontainer CLI refuses the file; re-run with: ${TARGET}" >&2
    exit 1
fi

mount_count="$(
    jq '[.mounts[]? | select(.type == "bind"
            and (.source | endswith("Code/devcontainers/config/env"))
            and .target == "/home/vscode/.config/cline/mcp"
            and (.options | index("ro")) != null)] | length' "$DEVCONTAINER_JSON"
)"
if [ "$mount_count" = "1" ]; then
    echo "ok   - devcontainer.json mounts the local env directory read-only"
else
    echo "FAIL - expected exactly 1 read-only bind mount of the local env dir," \
        "found ${mount_count}" >&2
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
fi

if jq -e '.remoteUser == "vscode"' "$DEVCONTAINER_JSON" >/dev/null; then
    echo "ok   - devcontainer.json runs as the vscode user the loader targets"
else
    echo "FAIL - devcontainer.json no longer sets remoteUser to vscode" >&2
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
fi

# ---------------------------------------------------------------------------
# 5. The prose still points at the two places env vars are read from.
# ---------------------------------------------------------------------------
expect_text "README documents the committed env file" \
    "cline_mcp_config.env" "$README"
expect_text "README documents the env template" \
    ".env.example" "$README"

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} environment-wiring assertion(s) failed" >&2
    echo "re-run with: ${TARGET}" >&2
    exit 1
fi

echo "SUCCESS: env loader loads and exports, the template declares every key," \
    "the shell bootstrap wires it once, and the mount stays read-only"
