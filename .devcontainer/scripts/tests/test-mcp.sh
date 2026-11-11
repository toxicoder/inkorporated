#!/bin/bash
# Asserts the shape of the non-secret MCP server configuration the devcontainer
# ships: both settings documents parse, every server declares a real launch
# command, only keys the Cline schema defines appear, credentials stay
# ${PLACEHOLDER} references rather than committed values, every catalogue server
# is toggleable, and the bootstrap scripts still name the files that exist here.
#
# Run it with: bazelisk test //.devcontainer/scripts/tests:test_mcp
#
# Nothing here echoes a value from the committed env file: that file is checked
# for line shape only. Real values live in .devcontainer/.env, which git never
# sees.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../../.." && pwd)"
DEVCONTAINER="${REPO_ROOT}/.devcontainer"
SCRIPTS="${DEVCONTAINER}/scripts"
SETTINGS="${DEVCONTAINER}/cline_mcp_settings.json"
SETTINGS_CATALOGUE="${DEVCONTAINER}/cline_mcp_setting.json.example"
MCP_ENV="${DEVCONTAINER}/cline_mcp_config.env"
CONFIG_TEMPLATE="${DEVCONTAINER}/devcontainer-config.env.example"
ENV_TEMPLATE="${DEVCONTAINER}/.env.example"
SETUP_MCP="${SCRIPTS}/core/setup-mcp.sh"
SETUP_FILES="${SCRIPTS}/core/setup-files.sh"
TARGET="bazelisk test //.devcontainer/scripts/tests:test_mcp"

failures=0

require_tool() {
    local tool="$1" install="$2"
    command -v "$tool" >/dev/null 2>&1 || {
        echo "FAIL - ${tool} is required by this lane; install it with: ${install}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    }
}

require_tool jq "apt-get install -y jq"
require_tool awk "apt-get install -y gawk or mawk"

for required in "$SETTINGS" "$SETTINGS_CATALOGUE" "$MCP_ENV" "$CONFIG_TEMPLATE" \
    "$ENV_TEMPLATE" "$SETUP_MCP" "$SETUP_FILES"; do
    if [ ! -f "$required" ]; then
        echo "FAIL - expected file is missing: ${required}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    fi
done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

fail() {
    local label="$1"
    shift
    echo "FAIL - ${label}" >&2
    for detail in "$@"; do
        echo "       ${detail}" >&2
    done
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
}

ok() {
    echo "ok   - $1"
}

# Keys the Cline mcpServers schema reads. Anything else is a key nobody consumes.
SERVER_SCHEMA='["alwaysAllow","args","autoApprove","command","disabled","env","timeout","transportType","type"]'

# jq helper shared by every per-server check: iterate entries as name/object.
ENTRIES='.mcpServers | to_entries[] | .key as $name | .value'

check_settings_shape() {
    local label="$1" file="$2"

    if ! jq -e . "$file" >/dev/null 2>&1; then
        fail "${label} is not valid JSON" "file: ${file}"
        return
    fi
    ok "${label} parses as JSON"

    local top_keys
    top_keys="$(jq -r 'keys[]' "$file" | sort | tr '\n' ' ')"
    if [ "$top_keys" != "mcpServers " ]; then
        fail "${label} must hold only mcpServers at the top level" "got: ${top_keys}"
        return
    fi

    local server_count
    server_count="$(jq '.mcpServers | length' "$file")"
    if [ "$server_count" -lt 1 ]; then
        fail "${label} declares no MCP servers" "count: ${server_count}"
        return
    fi
    ok "${label} declares ${server_count} server(s)"

    local bad_names
    bad_names="$(jq -r '.mcpServers | keys[] | select(test("^[a-z0-9][a-z0-9._-]*$") | not)' "$file" | tr '\n' ' ')"
    if [ -n "$bad_names" ]; then
        fail "${label} has server names outside [a-z0-9._-]" "names: ${bad_names}"
    else
        ok "${label} server names are all lowercase slugs"
    fi

    local no_command
    no_command="$(jq -r "${ENTRIES} | select((has(\"command\") | not) or ((.command | type) != \"string\") or ((.command | length) == 0)) | \$name" "$file" | tr '\n' ' ')"
    if [ -n "$no_command" ]; then
        fail "${label} has servers without a non-empty string command" "servers: ${no_command}"
    else
        ok "${label} every server declares a command to launch"
    fi

    local bad_args
    bad_args="$(jq -r "${ENTRIES} | select(has(\"args\")) | select((.args | type) != \"array\" or ([.args[] | select((type != \"string\") or (length == 0))] | length) > 0) | \$name" "$file" | tr '\n' ' ')"
    if [ -n "$bad_args" ]; then
        fail "${label} has servers whose args are not a list of non-empty strings" \
            "servers: ${bad_args}"
    else
        ok "${label} every args list is a list of non-empty strings"
    fi

    local bad_env
    bad_env="$(jq -r "${ENTRIES} | (.env // {}) | to_entries[] | select((.key | test(\"^[A-Z][A-Z0-9_]*$\") | not) or (.value | type != \"string\")) | \"\\(\$name)/\\(.key)\"" "$file" | tr '\n' ' ')"
    if [ -n "$bad_env" ]; then
        fail "${label} has env entries that are not UPPER_SNAKE keys with string values" \
            "entries: ${bad_env}"
    else
        ok "${label} every env entry is an UPPER_SNAKE key with a string value"
    fi

    local unknown_keys
    unknown_keys="$(jq -r "${ENTRIES} | keys[] | select(. as \$k | ${SERVER_SCHEMA} | index(\$k) | not) | \"\\(\$name):\\(.)\"" "$file" | tr '\n' ' ')"
    if [ -n "$unknown_keys" ]; then
        fail "${label} uses server keys the settings schema does not define" \
            "keys: ${unknown_keys}"
    else
        ok "${label} only uses keys the settings schema defines"
    fi

    local literal_secrets
    literal_secrets="$(jq -r "${ENTRIES} | (.env // {}) | to_entries[] | select(.key | test(\"(API_KEY|TOKEN|PASSWORD|SECRET|CREDENTIAL|PWD|URI)$\")) | select(.value | test(\"^\\\\\$\\\\{[A-Z][A-Z0-9_]*\\\\}\$\") | not) | \"\\(\$name)/\\(.key)\"" "$file" | tr '\n' ' ')"
    if [ -n "$literal_secrets" ]; then
        fail "${label} stores a credential-looking value that is not a placeholder" \
            "entries: ${literal_secrets}" \
            "credential values belong in .devcontainer/.env, never in a committed file"
    else
        ok "${label} keeps every credential-bearing env entry a placeholder reference"
    fi

    local placeholders
    placeholders="$(
        awk '{
                while (match($0, /\$\{[^}]*\}/)) {
                    print substr($0, RSTART, RLENGTH)
                    $0 = substr($0, RSTART + RLENGTH)
                }
              }' "$file" | sort -u
    )"
    if [ -z "$placeholders" ]; then
        fail "${label} references no placeholder at all" \
            "a settings file with no placeholder has no way to receive secrets"
    else
        local bad_placeholders
        bad_placeholders="$(
            awk '!/^\$\{[A-Z][A-Z0-9_]*\}$/ { printf "%s ", $0 }' <<<"$placeholders"
        )"
        if [ -n "$bad_placeholders" ]; then
            fail "${label} has malformed placeholders" "found: ${bad_placeholders}"
        else
            ok "${label} expands $(wc -l <<<"$placeholders") well-formed placeholder(s)"
        fi
    fi

    if grep -qE 'gh[pousr]_|xox[baprs]-|sk-[A-Za-z0-9]|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|[A-Za-z0-9+/]{32,}' \
        "$file"; then
        fail "${label} contains something that looks like a committed credential" \
            "this file is committed; real values come from .devcontainer/.env"
    else
        ok "${label} carries no credential shapes"
    fi
}

check_settings_shape "the shipped MCP settings" "$SETTINGS"
check_settings_shape "the MCP settings catalogue" "$SETTINGS_CATALOGUE"

# Every catalogue server must be toggleable from the env template, so a server
# nobody wants cannot start just because it is documented.
unmanaged="$(jq -r "${ENTRIES} | select(has(\"disabled\") | not) | \$name" "$SETTINGS_CATALOGUE" | tr '\n' ' ')"
if [ -n "$unmanaged" ]; then
    fail "catalogue servers with no disabled switch" "servers: ${unmanaged}"
else
    ok "every catalogue server has a disabled switch"
fi

not_templated="$(jq -r "${ENTRIES} | select(has(\"disabled\")) | select((.disabled | type) != \"string\" or (.disabled | test(\"^\\\\\$\\\\{[A-Z][A-Z0-9_]*\\\\}\$\") | not)) | \$name" "$SETTINGS_CATALOGUE" | tr '\n' ' ')"
if [ -n "$not_templated" ]; then
    fail "catalogue servers whose disabled switch is not a placeholder" \
        "servers: ${not_templated}"
else
    ok "every disabled switch is a placeholder the env file fills in"
fi

# ---------------------------------------------------------------------------
# The committed env file the bootstrap seeds the container with: line shape
# only, so a value is never printed into a test log.
# ---------------------------------------------------------------------------
bad_env_lines="$(
    awk '
        /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
        /^[A-Za-z_][A-Za-z0-9_]*=/ { next }
        { bad++ }
        END { print bad + 0 }
    ' "$MCP_ENV"
)"
if [ "$bad_env_lines" = "0" ]; then
    ok "cline_mcp_config.env is only comments, blanks, and KEY=assignments"
else
    fail "${bad_env_lines} line(s) in cline_mcp_config.env are not KEY=assignments" \
        "the bootstrap sources this file with set -a, so a bad line is a broken shell"
fi

if [ -s "$MCP_ENV" ]; then
    ok "cline_mcp_config.env is not empty"
else
    fail "cline_mcp_config.env is empty; setup-mcp.sh would seed an empty config"
fi

# Every key the env template documents must be a legal shell name, since the
# loader exports the whole file with set -a.
bad_template="$(
    awk '
        /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
        /^[A-Za-z_][A-Za-z0-9_]*=/ { next }
        { bad++ }
        END { print bad + 0 }
    ' "$ENV_TEMPLATE"
)"
if [ "$bad_template" = "0" ]; then
    ok ".env.example is only comments, blanks, and KEY=assignments"
else
    fail "${bad_template} line(s) in .env.example are not KEY=assignments"
fi

# ---------------------------------------------------------------------------
# The bootstrap must still name the files that exist here, or the container
# starts with no MCP servers configured and nothing fails.
# ---------------------------------------------------------------------------
expect_in() {
    local label="$1" needle="$2" file="$3"
    if grep -qF -- "$needle" "$file"; then
        ok "${label}"
    else
        fail "${label}" "expected to find '${needle}' in $(basename "$file")"
    fi
}

expect_in "setup-files.sh copies the shipped MCP settings" \
    "cline_mcp_settings.json" "$SETUP_FILES"
expect_in "setup-files.sh locks the copied env file to mode 600" \
    "chmod 600" "$SETUP_FILES"
expect_in "setup-files.sh seeds the Cline settings directory" \
    "saoudrizwan.claude-dev/settings" "$SETUP_FILES"
expect_in "setup-mcp.sh seeds the committed MCP env file" \
    "cline_mcp_config.env" "$SETUP_MCP"

# The documented settings path has to resolve inside the checkout once the
# container prefix is stripped, otherwise the editor reads a file nobody writes.
documented_path="$(sed -n 's|^SETTINGS_FILE_PATH="\(/workspaces/inkorporated/\)\{0,1\}\(.*\)"$|\2|p' \
    "$CONFIG_TEMPLATE" | head -1)"
if [ -z "$documented_path" ]; then
    fail "devcontainer-config.env.example declares no SETTINGS_FILE_PATH"
elif [ -f "${REPO_ROOT}/${documented_path}" ]; then
    ok "the documented SETTINGS_FILE_PATH resolves to ${documented_path}"
else
    fail "SETTINGS_FILE_PATH points at a file that does not exist" \
        "resolved to: ${documented_path}"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} MCP configuration assertion(s) failed" >&2
    echo "re-run with: ${TARGET}" >&2
    exit 1
fi

echo "SUCCESS: both MCP settings documents parse, keep credentials as placeholders," \
    "stay inside the schema, and the bootstrap still names the files it copies"
