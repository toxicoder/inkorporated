#!/bin/bash
# Asserts the file operations the devcontainer bootstrap depends on: the
# find-delete scoping it uses to clear generated files, symlink-safe delete,
# the copy-and-lock sequence that installs the MCP settings and the mode-600
# rule that protects the copied env file, and the guarantee that the bootstrap
# writes nothing the checkout tracks.
#
# Run it with: bazelisk test //.devcontainer/scripts/tests:test_file_utils
#
# The bootstrap is exercised on a temp copy whose container paths are rewritten
# into mktemp, so the copy/chmod behaviour is observed rather than grepped for,
# and nothing here can touch the checkout or the developer's home directory.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../../.." && pwd)"
DEVCONTAINER="${REPO_ROOT}/.devcontainer"
SCRIPTS="${DEVCONTAINER}/scripts"
SETUP_FILES="${SCRIPTS}/core/setup-files.sh"
SETUP_MCP="${SCRIPTS}/core/setup-mcp.sh"
SETUP_SHELL="${SCRIPTS}/core/setup-shell.sh"
SETTINGS="${DEVCONTAINER}/cline_mcp_settings.json"
MCP_ENV="${DEVCONTAINER}/cline_mcp_config.env"
TARGET="bazelisk test //.devcontainer/scripts/tests:test_file_utils"

failures=0

require_tool() {
    local tool="$1" install="$2"
    command -v "$tool" >/dev/null 2>&1 || {
        echo "FAIL - ${tool} is required by this lane; install it with: ${install}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    }
}

require_tool find "apt-get install -y findutils"
require_tool cmp "apt-get install -y diffutils"
require_tool stat "apt-get install -y coreutils"
require_tool jq "apt-get install -y jq"
require_tool git "apt-get install -y git"

for required in "$SETUP_FILES" "$SETUP_MCP" "$SETUP_SHELL" "$SETTINGS" "$MCP_ENV"; do
    if [ ! -f "$required" ]; then
        echo "FAIL - expected file is missing: ${required}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    fi
done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

BASH_PATH="$(command -v bash)"
GIT_BEFORE="$(git -C "$REPO_ROOT" status --porcelain)"

ok() {
    echo "ok   - $1"
}

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

# ---------------------------------------------------------------------------
# 1. find -delete removes only what it names, and leaves the tree structure
#    alone. This is how generated files get cleared under the workspace.
# ---------------------------------------------------------------------------
TREE="${WORKDIR}/tree"
mkdir -p "${TREE}/nested/deeper"
for name in a.txt b.txt c.md d.md; do
    echo "content ${name}" >"${TREE}/${name}"
done
echo "deep" >"${TREE}/nested/keep.txt"
echo "deep" >"${TREE}/nested/deeper/deep.txt"

find "$TREE" -name '*.txt' -delete

leftover_txt="$(find "$TREE" -name '*.txt' | wc -l)"
if [ "$leftover_txt" = "0" ]; then
    ok "find -delete removed every .txt file, nested ones included"
else
    fail "find -delete left ${leftover_txt} .txt file(s) behind" \
        "the bootstrap clears generated files this way"
fi

survivors=0
for name in c.md d.md; do
    [ -f "${TREE}/${name}" ] || survivors=$((survivors + 1))
done
if [ "$survivors" = "0" ]; then
    ok "the files find -delete was not told to remove are untouched"
else
    fail "find -delete removed ${survivors} file(s) it was not asked to remove"
fi

if [ -d "${TREE}/nested/deeper" ]; then
    ok "find -delete left the directory tree in place"
else
    fail "find -delete removed directories, not just the matched files"
fi

# ---------------------------------------------------------------------------
# 2. Recursive delete takes the subtree and nothing else.
# ---------------------------------------------------------------------------
mkdir -p "${WORKDIR}/sibling"
echo "keep me" >"${WORKDIR}/sibling/keep"
rm -rf "${TREE}/nested"
if [ ! -e "${TREE}/nested" ] && [ -f "${WORKDIR}/sibling/keep" ]; then
    ok "rm -rf took the subtree and left its sibling alone"
else
    fail "rm -rf did not confine itself to the named subtree"
fi

# ---------------------------------------------------------------------------
# 3. Deleting a symlink must not follow it, and cp -f over a symlink must write
#    through it. The editor profile holds the Cline settings as a symlink into
#    the checkout, so both halves of that behaviour have to hold.
# ---------------------------------------------------------------------------
REAL="${WORKDIR}/real-settings.json"
LINK="${WORKDIR}/linked-settings.json"
cp "$SETTINGS" "$REAL"
ln -s "$REAL" "$LINK"
rm -f "$LINK"
if [ ! -e "$LINK" ] && [ -f "$REAL" ] && cmp -s "$SETTINGS" "$REAL"; then
    ok "removing a symlink left its target intact"
else
    fail "removing a symlink damaged its target" \
        "the editor profile holds settings as symlinks"
fi

ln -s "$REAL" "$LINK"
echo '{"mcpServers":{}}' >"${WORKDIR}/replacement.json"
cp -f "${WORKDIR}/replacement.json" "$LINK"
if cmp -s "${WORKDIR}/replacement.json" "$REAL"; then
    ok "cp -f over a symlink updated the file the symlink points at"
else
    fail "cp -f over a symlink replaced the link instead of writing through it" \
        "the container relies on this to refresh Cline settings in place"
fi

# ---------------------------------------------------------------------------
# 4. Run the bootstrap's file stage for real, against a rewritten copy of the
#    script, and observe what it does.
# ---------------------------------------------------------------------------
CONTAINER="${WORKDIR}/container"
FAKE_HOME="${CONTAINER}/home/vscode"
FAKE_WS="${CONTAINER}/workspaces/inkorporated"
mkdir -p "${FAKE_WS}/.devcontainer" "$FAKE_HOME"
cp "$SETTINGS" "${FAKE_WS}/.devcontainer/cline_mcp_settings.json"
cp "$MCP_ENV" "${FAKE_WS}/.devcontainer/cline_mcp_config.env"

RUN_SCRIPT="${WORKDIR}/run-setup-files.sh"
sed -e 's|^[[:space:]]*cd[[:space:]].*npm install.*|: dependency install is out of scope for this lane|' \
    -e "s|/home/vscode|${FAKE_HOME}|g" \
    -e "s|/workspaces/inkorporated|${FAKE_WS}|g" \
    "$SETUP_FILES" >"$RUN_SCRIPT"

settings_target="${FAKE_HOME}/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
env_target="${FAKE_HOME}/.config/cline/mcp/cline_mcp_config.env"

status=0
"$BASH_PATH" "$RUN_SCRIPT" >"${WORKDIR}/first-run.log" 2>&1 || status=$?
if [ "$status" = "0" ]; then
    ok "the file stage of the bootstrap completes on a fresh container home"
else
    fail "the file stage of the bootstrap exited ${status}" \
        "output: $(tail -3 "${WORKDIR}/first-run.log" | tr '\n' ' ')"
fi

if [ -f "$settings_target" ] && cmp -s "$SETTINGS" "$settings_target"; then
    ok "the shipped MCP settings reach the editor profile byte for byte"
else
    fail "the MCP settings did not reach the editor profile unchanged" \
        "expected at: ${settings_target#"${WORKDIR}/"}"
fi

if [ -f "$env_target" ]; then
    env_mode="$(stat -c '%a' "$env_target")"
    if [ "$env_mode" = "600" ]; then
        ok "the copied MCP env file lands locked to mode 600"
    else
        fail "the copied MCP env file is mode ${env_mode}, expected 600" \
            "it carries operator credentials into the container"
    fi
else
    fail "the MCP env file was not copied into the container home" \
        "expected at: ${env_target#"${WORKDIR}/"}"
fi

if [ -f "${FAKE_WS}/package.json" ] && jq -e . "${FAKE_WS}/package.json" >/dev/null 2>&1; then
    ok "the bootstrap creates a parseable package.json when none exists"
else
    fail "the bootstrap did not create a parseable package.json"
fi

status=0
"$BASH_PATH" "$RUN_SCRIPT" >>"${WORKDIR}/first-run.log" 2>&1 || status=$?
settings_copies="$(find "$(dirname "$settings_target")" -maxdepth 1 -type f | wc -l)"
if [ "$status" = "0" ] && [ "$settings_copies" = "1" ] \
    && cmp -s "$SETTINGS" "$settings_target"; then
    ok "a second run is idempotent: one settings file, still faithful"
else
    fail "a second run changed the result (exit ${status}, ${settings_copies} settings file(s))"
fi

# With no committed env file to seed from, the stage must still succeed and must
# not leave a half-written credentials file behind.
rm -f "${FAKE_WS}/.devcontainer/cline_mcp_config.env" "$env_target"
status=0
"$BASH_PATH" "$RUN_SCRIPT" >>"${WORKDIR}/first-run.log" 2>&1 || status=$?
if [ "$status" = "0" ] && [ ! -e "$env_target" ]; then
    ok "a missing env file is skipped cleanly instead of half-copied"
else
    fail "the file stage mishandled a missing env file (exit ${status})"
fi

if grep -qE 'chmod[[:space:]]+600' "$SETUP_FILES"; then
    ok "setup-files.sh still names the 600 lock for the copied env file"
else
    fail "setup-files.sh no longer chmods the copied MCP env file"
fi

# ---------------------------------------------------------------------------
# 5. Static guards: the bootstrap must never rewrite the checkout.
# ---------------------------------------------------------------------------
for script in "$SETUP_FILES" "$SETUP_MCP" "$SETUP_SHELL"; do
    name="$(basename "$script")"
    if grep -qE '\bsed[[:space:]]+-[A-Za-z]*i\b' "$script"; then
        fail "${name} runs an in-place sed" \
            "in-place edits rewrite the checkout during container setup"
    else
        ok "${name} runs no in-place sed"
    fi

    if grep -qE '(^|[^[:alnum:]_])git([[:space:]]|$)' "$script"; then
        fail "${name} calls git" "setup scripts should not touch the repository state"
    else
        ok "${name} does not touch git state"
    fi
done

# package.json is tracked in this repository, so the bootstrap may create it but
# must never overwrite it: seed a sentinel and prove it survives a run.
SENTINEL='{"sentinel":true}'
printf '%s\n' "$SENTINEL" >"${FAKE_WS}/package.json"
status=0
"$BASH_PATH" "$RUN_SCRIPT" >>"${WORKDIR}/first-run.log" 2>&1 || status=$?
if [ "$status" = "0" ] && [ "$(cat "${FAKE_WS}/package.json")" = "$SENTINEL" ]; then
    ok "the bootstrap leaves an existing package.json alone"
else
    fail "the bootstrap overwrote package.json, which this repository tracks" \
        "an existing workspace file was replaced during container setup"
fi

guarded="$(
    awk '
        /if \[ ! -f "?[^"[:space:]]*package\.json"? \]/ { guard = NR }
        /cat[[:space:]]+>[[:space:]]*"?[^"[:space:]]*package\.json/ {
            if (guard && NR - guard <= 6) { found = 1 }
        }
        END { print found ? "yes" : "no" }
    ' "$SETUP_FILES"
)"
if [ "$guarded" = "yes" ]; then
    ok "the package.json write stays behind an existence guard"
else
    fail "the package.json write is no longer guarded by an existence check" \
        "without the guard the bootstrap clobbers a tracked file on every start"
fi

GIT_AFTER="$(git -C "$REPO_ROOT" status --porcelain)"
if [ "$GIT_BEFORE" = "$GIT_AFTER" ]; then
    ok "this lane left the checkout untouched"
else
    fail "this lane modified the checkout" \
        "git status changed from:" "${GIT_BEFORE}" "to:" "${GIT_AFTER}"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} file-utility assertion(s) failed" >&2
    echo "re-run with: ${TARGET}" >&2
    exit 1
fi

echo "SUCCESS: find-delete scoping, symlink-safe delete, write-through copy," \
    "the bootstrap's mode-600 lock observed by running it, and no writes into the checkout"
