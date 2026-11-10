#!/bin/bash
# The entry-point contract of validate_config.sh: it is a real program at the repo
# root (bash shebang, executable, parses), it documents every flag it accepts, it
# exits 0 only for a config file that is actually fine, and it exits 1 when the
# file is missing, unreadable, or wrong. The assertion this lane replaces accepted
# either exit code 0 or 1, so the validator could report nothing and still pass.
#
# Run it with: bazelisk test //tests/config:test_validation_script
#
# Broken inputs are fixtures under mktemp; the checkout is never written to. The
# operator's secrets file is never opened: it is gitignored and belongs to
# //:validate_config.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
VALIDATOR="${REPO_ROOT}/validate_config.sh"
TEMPLATE="${REPO_ROOT}/.devcontainer/.env.example"
ALLOWLIST="${REPO_ROOT}/tools/bazel/secrets-allowlist.txt"
TARGET="bazelisk test //tests/config:test_validation_script"

failures=0

ok() {
    echo "ok   - $1"
}

fail() {
    local label="$1"
    shift
    local detail
    echo "FAIL - ${label}" >&2
    for detail in "$@"; do
        echo "       ${detail}" >&2
    done
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
}

require_tool() {
    local tool="$1" install="$2"
    command -v "$tool" >/dev/null 2>&1 || {
        echo "FAIL - ${tool} is required by this lane; install it with: ${install}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    }
}

require_tool bash "apt-get install -y bash"
require_tool grep "apt-get install -y grep"
require_tool timeout "apt-get install -y coreutils"

if [ ! -f "$VALIDATOR" ]; then
    echo "FAIL - the validator the lane tests is missing: ${VALIDATOR}" >&2
    echo "       re-run with: ${TARGET}" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# run_validator <cwd> <args...> : echo combined output, return the exit status.
# Bounded by timeout: a validator that hangs is a validator that never fails, and
# an unbounded wait would take the gate with it.
run_validator() {
    local cwd="$1"
    shift
    local status=0
    if (cd "$cwd" && timeout 60 "$VALIDATOR" "$@") >"${WORKDIR}/out" 2>&1; then
        status=0
    else
        status=$?
    fi
    cat "${WORKDIR}/out"
    return "$status"
}

# check_exit <expected> <label> <cwd> <args...> : the exit code has to be the one
# the contract states, not merely "not a crash". Prints the captured output when
# the code matches, and fails the lane when it does not.
check_exit() {
    local expected="$1" label="$2" cwd="$3"
    shift 3
    local status=0 out=""
    if (cd "$cwd" && timeout 60 "$VALIDATOR" "$@") >"${WORKDIR}/out" 2>&1; then
        status=0
    else
        status=$?
    fi
    out="$(cat "${WORKDIR}/out")"
    if [ "$status" -ne "$expected" ]; then
        fail "${label} (exit ${status}, expected ${expected})" \
            "args: $*" \
            "output: $(printf '%s' "$out" | tr '\n' ' ' | head -c 300)"
        return 1
    fi
    printf '%s' "$out"
    return 0
}

# --- the script is a real program ------------------------------------------
if head -1 "$VALIDATOR" | grep -Eq '^#!(/bin/bash|/usr/bin/env bash|/bin/env bash)$'; then
    ok "validate_config.sh has a bash shebang"
else
    fail "validate_config.sh does not have a bash shebang" \
        "first line: $(head -1 "$VALIDATOR")"
fi

if [ -x "$VALIDATOR" ]; then
    ok "validate_config.sh is executable"
else
    fail "validate_config.sh is not executable" \
        "the gate runs it directly, so the mode bit is part of the contract"
fi

if bash -n "$VALIDATOR" 2>"${WORKDIR}/syntax"; then
    ok "validate_config.sh parses as bash"
else
    fail "validate_config.sh does not parse as bash" \
        "$(head -5 "${WORKDIR}/syntax")"
fi

# The usage line has to name every flag the parser accepts, otherwise a flag can
# be added that nobody can discover.
accepted_flags="$(sed -n 's/^[[:space:]]*\(--[a-z-]*)\)[[:space:]]*$/\1/p' "$VALIDATOR" \
    | tr -d ')')"
if [ -n "$accepted_flags" ]; then
    ok "the argument parser accepts $(printf '%s\n' "$accepted_flags" | grep -c .) flag(s)"
else
    fail "the argument parser in validate_config.sh could not be read" \
        "no --flag) pattern was found; the flag contract is untestable"
fi

status=0
usage="$(run_validator "$REPO_ROOT" --no-such-flag)" || status=$?
undocumented=""
while IFS= read -r flag; do
    [ -n "$flag" ] || continue
    if ! printf '%s' "$usage" | grep -qF -- "$flag"; then
        undocumented="${undocumented} ${flag}"
    fi
done <<<"$accepted_flags"
if [ -z "$undocumented" ]; then
    ok "the usage line documents every flag the parser accepts"
else
    fail "the usage line omits flags the parser accepts" \
        "undocumented:${undocumented}"
fi

if [ "$status" -eq 2 ] && printf '%s' "$usage" | grep -q 'Unknown argument'; then
    ok "an unknown argument is refused with usage (exit 2)"
else
    fail "an unknown argument was not refused with exit 2 (got ${status})" \
        "a validator that ignores an unknown flag validates a file nobody asked about" \
        "output: $(printf '%s' "$usage" | tr '\n' ' ' | head -c 300)"
fi

# A flag that takes a value has to be given one. `shift 2` on a single argument
# leaves the parser looking at the same word forever, so the case that used to
# hang the validator is asserted here with a bounded wait.
for truncated in --config-file --allowlist; do
    status=0
    out="$(check_exit 2 "the truncated flag ${truncated} is refused" "$REPO_ROOT" \
        "$truncated")" || status=$?
    if [ "$status" -eq 0 ]; then
        if printf '%s' "$out" | grep -qF -- "${truncated} requires a value"; then
            ok "${truncated} without a value says which flag is at fault"
        else
            fail "${truncated} without a value did not name the flag" \
                "an operator reading 'expected one argument' cannot act on it" \
                "output: $(printf '%s' "$out" | tr '\n' ' ' | head -c 300)"
        fi
    fi
done

# --- missing and unreadable inputs -----------------------------------------
status=0
out="$(check_exit 1 "a missing config file is refused in operator mode" "$REPO_ROOT" \
    --config-file "${WORKDIR}/absent.env")" || status=$?
if [ "$status" -eq 0 ]; then
    if printf '%s' "$out" | grep -qF -- "${WORKDIR}/absent.env"; then
        ok "it names the file it could not find"
    else
        fail "it did not name the missing file" \
            "an operator cannot act on a failure that does not say what is missing" \
            "output: $(printf '%s' "$out" | tr '\n' ' ' | head -c 300)"
    fi
fi

status=0
out="$(check_exit 1 "a missing template is refused in template mode" "$REPO_ROOT" \
    --config-file "${WORKDIR}/absent.env" --template)" || status=$?
if [ "$status" -eq 0 ]; then
    if printf '%s' "$out" | grep -qi 'committed template is missing'; then
        ok "template mode says so when the committed template is gone"
    else
        fail "template mode did not distinguish a missing template" \
            "output: $(printf '%s' "$out" | tr '\n' ' ' | head -c 300)"
    fi
fi

# --- the committed template: the lane the gate relies on --------------------
status=0
out="$(check_exit 0 "the committed template passes template validation" "$REPO_ROOT" \
    --config-file "$TEMPLATE" --template --allowlist "$ALLOWLIST")" || status=$?
if [ "$status" -eq 0 ]; then
    if printf '%s' "$out" | grep -q 'Template validation complete'; then
        ok "it reports completion rather than falling off the end"
    else
        fail "it exited 0 without reporting completion" \
            "an early return and a real pass look identical from the exit code alone" \
            "output: $(printf '%s' "$out" | tr '\n' ' ' | head -c 300)"
    fi
    if printf '%s' "$out" | grep -qF -- "Configuration file found: ${TEMPLATE}"; then
        ok "it read the file the lane handed it"
    else
        fail "it did not report reading the config file it was given" \
            "output: $(printf '%s' "$out" | tr '\n' ' ' | head -c 300)"
    fi
    if printf '%s' "$out" | grep -q 'Secrets allowlist in use'; then
        ok "it reports the allowlist it consulted"
    else
        fail "it did not report the allowlist it consulted" \
            "a secret scanner that never says which ledger it read can read none" \
            "output: $(printf '%s' "$out" | tr '\n' ' ' | head -c 300)"
    fi
fi

status=0
out="$(check_exit 0 "template validation still passes with a missing allowlist" "$REPO_ROOT" \
    --config-file "$TEMPLATE" --template --allowlist "${WORKDIR}/absent-ledger.txt")" || status=$?
if [ "$status" -eq 0 ]; then
    if printf '%s' "$out" | grep -q 'Secrets allowlist in use'; then
        fail "it claimed an allowlist was in use when the path does not exist" \
            "the ledger is the thing standing between a false positive and a green gate" \
            "output: $(printf '%s' "$out" | tr '\n' ' ' | head -c 300)"
    else
        ok "it does not claim an allowlist it could not read"
    fi
fi

# --- the exit code carries information --------------------------------------
# This is the assertion the old `[ $? -eq 0 ] || [ $? -eq 1 ]` test replaced: the
# same program has to answer 0 for a good file and 1 for a bad one.
good_fixture="${WORKDIR}/good.env"
{
    printf 'GH_TOKEN=YOUR_GH_TOKEN_HERE\n'
    printf 'PERPLEXITY_API_KEY=YOUR_PERPLEXITY_API_KEY_HERE\n'
    printf 'TAVILY_API_KEY=YOUR_TAVILY_API_KEY_HERE\n'
    printf 'MCP_MONGODB_URI=YOUR_MCP_MONGODB_URI_HERE\n'
    printf 'REDIS_PWD=YOUR_REDIS_PWD_HERE\n'
    printf 'SLACK_MCP_XOXC_TOKEN=YOUR_SLACK_MCP_XOXC_TOKEN_HERE\n'
} >"$good_fixture"

broken_fixture="${WORKDIR}/broken.env"
grep -v '^REDIS_PWD=' "$good_fixture" >"$broken_fixture"

status=0
run_validator "$REPO_ROOT" --config-file "$good_fixture" --template \
    --allowlist "$ALLOWLIST" >/dev/null || status=$?
if [ "$status" -ne 0 ]; then
    fail "a well-formed template did not exit 0 (got ${status})" \
        "the fixture is built from the keys the validator itself requires"
else
    ok "a well-formed template exits 0"
fi

status=0
run_validator "$REPO_ROOT" --config-file "$broken_fixture" --template \
    --allowlist "$ALLOWLIST" >/dev/null || status=$?
if [ "$status" -eq 0 ]; then
    fail "the validator returned 0 for a template with a required key removed" \
        "removing REDIS_PWD has to be visible in the exit code" \
        "this is exactly the vacuous pass the old 0-or-1 test allowed"
elif [ "$status" -ne 1 ]; then
    fail "the validator used an unexpected exit code for a broken template (got ${status})" \
        "the contract is 0 for good, 1 for a failed validation, 2 for a usage error"
else
    ok "the exit code separates a good template from a broken one (0 vs 1)"
fi

# --- it does not depend on the caller's cwd when handed paths ---------------
status=0
run_validator "$WORKDIR" --config-file "$TEMPLATE" --template \
    --allowlist "$ALLOWLIST" >/dev/null || status=$?
if [ "$status" -ne 0 ]; then
    fail "template validation depends on the caller's cwd (got ${status})" \
        "the Bazel target runs it from runfiles, not from the checkout"
else
    ok "template validation works from an unrelated directory"
fi

status=0
out="$(check_exit 1 "no arguments from an unrelated directory is a failure, not a pass" "$WORKDIR")" ||
    status=$?
if [ "$status" -eq 0 ]; then
    if printf '%s' "$out" | grep -q 'not found'; then
        ok "it refuses rather than passing when its default config path is absent"
    else
        fail "it did not explain why running with no arguments failed" \
            "output: $(printf '%s' "$out" | tr '\n' ' ' | head -c 300)"
    fi
fi

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} validation-script assertion(s) failed" >&2
    exit 1
fi

echo "SUCCESS: validate_config.sh is a real program, documents its flags, reads the" \
    "file it is handed, and answers 0 / 1 / 2 for good / broken / misuse"
