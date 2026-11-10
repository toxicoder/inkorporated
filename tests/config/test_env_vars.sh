#!/bin/bash
# Asserts what the environment-variable lane promises: the committed devcontainer
# template declares every key validate_config.sh requires, loads into a shell
# through both idioms the repository documents, keeps every credential-bearing
# value a placeholder, and that validate_config.sh really rejects a template that
# does not. Every negative case runs against a fixture under mktemp, so the lane
# proves the validator can fail rather than proving it agrees with a good file.
#
# Run it with: bazelisk test //tests/config:test_env_vars
#
# Nothing here opens the operator's secrets file: it is gitignored and belongs to
# //:validate_config. The committed template is read for its line shape and key
# names, and no value from it is ever printed into this log.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
VALIDATOR="${REPO_ROOT}/validate_config.sh"
TEMPLATE="${REPO_ROOT}/.devcontainer/.env.example"
ALLOWLIST="${REPO_ROOT}/tools/bazel/secrets-allowlist.txt"
TARGET="bazelisk test //tests/config:test_env_vars"

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
require_tool awk "apt-get install -y gawk or mawk"

for required in "$VALIDATOR" "$TEMPLATE" "$ALLOWLIST"; do
    if [ ! -f "$required" ]; then
        echo "FAIL - expected file is missing: ${required}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    fi
done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---------------------------------------------------------------------------
# The required keys come from the validator itself, so the template and the
# validator cannot drift apart without this lane saying so.
# ---------------------------------------------------------------------------
if ! grep -qE '^REQUIRED_VARS=\($' "$VALIDATOR"; then
    echo "FAIL - validate_config.sh no longer declares a REQUIRED_VARS array" >&2
    echo "       file: ${VALIDATOR}" >&2
    echo "       the template cannot be checked against an undocumented list" >&2
    echo "       re-run with: ${TARGET}" >&2
    exit 1
fi

required_vars=()
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        'REQUIRED_VARS=(' | ')') ;;
        *) required_vars+=("$(printf '%s' "$line" | tr -d '[:space:]"')") ;;
    esac
done < <(sed -n '/^REQUIRED_VARS=(/,/^)/p' "$VALIDATOR")

if [ "${#required_vars[@]}" -lt 1 ]; then
    echo "FAIL - the REQUIRED_VARS array in validate_config.sh is empty" >&2
    echo "       an empty requirement list means no operator ever has to configure" >&2
    echo "       re-run with: ${TARGET}" >&2
    exit 1
fi
ok "validate_config.sh requires ${#required_vars[@]} key(s)"

# Every key the template declares, in file order, as KEY names only. Values are
# never read out of the committed file. The trailing-newline guard matters: the
# committed template has no final newline, and a plain `read` loop drops the last
# line without it, which would hide a required key.
template_keys=()
while IFS= read -r line || [ -n "$line" ]; do
    template_keys+=("$line")
done < <(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*$/\1/p' "$TEMPLATE")

if [ "${#template_keys[@]}" -gt 0 ]; then
    ok "the committed template declares ${#template_keys[@]} environment variable(s)"
else
    fail "the committed template declares no environment variable at all" \
        "file: ${TEMPLATE}"
fi

has_key() {
    local want="$1" key
    for key in "${template_keys[@]}"; do
        if [ "$key" = "$want" ]; then
            return 0
        fi
    done
    return 1
}

count_key() {
    local want="$1" key count=0
    for key in "${template_keys[@]}"; do
        if [ "$key" = "$want" ]; then
            count=$((count + 1))
        fi
    done
    printf '%s' "$count"
}

missing=""
duplicated=""
for var in "${required_vars[@]}"; do
    if ! has_key "$var"; then
        missing="${missing} ${var}"
    fi
    if [ "$(count_key "$var")" -gt 1 ]; then
        duplicated="${duplicated} ${var}x$(count_key "$var")"
    fi
done

if [ -z "$missing" ]; then
    ok "the template declares every required key (${#required_vars[@]} of them)"
else
    fail "the template does not declare every required key" \
        "missing:${missing}" \
        "file: ${TEMPLATE}" \
        "validate_config.sh requires these in template mode"
fi

if [ -z "$duplicated" ]; then
    ok "no required key is declared twice in the template"
else
    fail "a required key is declared twice in the template" \
        "duplicated:${duplicated}" \
        "the last assignment wins when the file is sourced, so the first is a trap"
fi

# Line shape: only comments, blanks, and KEY=VALUE assignments survive a loader
# that sources the file under set -a.
bad_lines="$(
    awk '
        /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
        /^[A-Za-z_][A-Za-z0-9_]*=/ { next }
        { bad++ }
        END { print bad + 0 }
    ' "$TEMPLATE"
)"
if [ "$bad_lines" = "0" ]; then
    ok "the template is only comments, blanks, and KEY=VALUE assignments"
else
    fail "${bad_lines} line(s) in the template are not KEY=VALUE assignments" \
        "file: ${TEMPLATE}" \
        "a loader that sources it with set -a turns such a line into a broken shell"
fi

# A credential-shaped value must never be committed in the template. It is a
# predicate, so a planted fixture can prove the guard rejects as well as accept.
credential_re='-----BEGIN [A-Z0-9 ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[0-9A-Za-z]{20,}|xox[baprs]-|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'

carries_credential_shape() {
    grep -qE -e "$credential_re" -- "$1" 2>/dev/null
}

if carries_credential_shape "$TEMPLATE"; then
    fail "the committed template carries a credential-shaped value" \
        "file: ${TEMPLATE}" \
        "a committed template holds placeholders; real values live in the" \
        "gitignored operator file, which no lane here reads"
else
    ok "the committed template holds no credential-shaped value"
fi

# Prove that guard is live on a temp copy, with the planted value assembled from
# parts so this file never holds a string the secret scanner would report.
planted_head='gh'
planted_mid='s_'
planted_body='0123456789abcdefABCDEF0123456789'
planted_copy="${WORKDIR}/planted-template"
printf '%s=%s\n' "${required_vars[0]}" "${planted_head}${planted_mid}${planted_body}" \
    >"$planted_copy"
if carries_credential_shape "$planted_copy"; then
    ok "the credential-shape guard rejects a planted value (proved on a temp copy)"
else
    fail "the credential-shape guard accepted a planted credential" \
        "the guard above is decoration, not a check"
fi

# ---------------------------------------------------------------------------
# Loading: both idioms the repository documents have to put every declared key in
# the environment carrying the value the file assigns. Each case runs in a clean
# env -i child, so a variable the test environment already exports cannot make an
# assertion pass. The child compares values but reports key names only, so no
# value from a config file reaches this log.
# ---------------------------------------------------------------------------
cat >"${WORKDIR}/load-and-audit.sh" <<'CHILD'
# $1 = file, $2 = mechanism. The two mechanisms are the ones the repository
# documents: env-loader.sh sources under set -a, and validate_config.sh prints
# the export/grep/xargs idiom as the operator's next step.
set -eu
case "$2" in
    source)
        set -a
        . "$1"
        set +a
        ;;
    export)
        export $(grep -v '^#' "$1" | xargs)
        ;;
    *)
        printf 'unknown loading mechanism\n'
        exit 2
        ;;
esac

problems=""
number=0
while IFS= read -r line || [ -n "$line" ]; do
    number=$((number + 1))
    case "$line" in
        '' | '#'*) continue ;;
    esac
    case "$line" in
        [A-Za-z_]*=*) ;;
        *) problems="${problems} line${number}:not-an-assignment"; continue ;;
    esac
    key="${line%%=*}"
    want="$(printf '%s' "${line#*=}" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/")"
    if [ "${!key-unset}" != "$want" ]; then
        problems="${problems} ${key}"
    fi
done <"$1"
if [ -n "$problems" ]; then
    printf 'MISMATCH:%s\n' "$problems"
    exit 9
fi
env | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*$/\1/p' | sort
CHILD

# loader_problems <mechanism> <file> : describe what the loader got wrong for that
# file, or print nothing when it exported exactly the declared keys and values.
loader_problems() {
    local mechanism="$1" file="$2" loaded declared key extra
    local problems=""
    if ! loaded="$(env -i PATH="$PATH" HOME="$WORKDIR" bash "${WORKDIR}/load-and-audit.sh" \
        "$file" "$mechanism" 2>&1)"; then
        printf 'the %s loader rejected the file: %.200s\n' "$mechanism" "$loaded"
        return 0
    fi
    declared="$(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*$/\1/p' "$file" | sort -u)"
    while IFS= read -r key; do
        [ -n "$key" ] || continue
        if ! printf '%s\n' "$loaded" | grep -qx -- "$key"; then
            problems="${problems}it did not export ${key}"$'\n'
        fi
    done <<<"$declared"
    extra="$(comm -13 <(printf '%s\n' "$declared") <(printf '%s\n' "$loaded" | sort -u) \
        | grep -vE '^(HOME|PATH|PWD|SHLVL|_)$' | tr '\n' ' ' || true)"
    if [ -n "$extra" ]; then
        problems="${problems}it exported keys the file does not declare: ${extra% }"$'\n'
    fi
    printf '%s' "$problems"
}

check_loader() {
    local label="$1" mechanism="$2" file="$3" problems
    problems="$(loader_problems "$mechanism" "$file")"
    if [ -n "$problems" ]; then
        fail "${label}" \
            "file: ${file#"${WORKDIR}/"}" \
            "$(printf '%s' "$problems" | sed -e '/^$/d' -e 's/^/  /')"
    else
        ok "${label}"
    fi
}

check_loader "sourcing under set -a loads every key the template declares" \
    source "$TEMPLATE"
check_loader "the documented export \$(grep ... | xargs) idiom loads every declared key" \
    export "$TEMPLATE"

# Neither case above can pass by matching nothing, and neither can the loader
# child: both halves are exercised against fixtures the template does not have.

# A key the shell refuses to export has to be caught by both idioms.
badkey_copy="${WORKDIR}/badkey-template"
{
    printf 'bad-key=1\n'
    printf '%s=\n' "${template_keys[@]}"
} >"$badkey_copy"
for mechanism in source export; do
    if [ -n "$(loader_problems "$mechanism" "$badkey_copy")" ]; then
        ok "the ${mechanism} loader check notices a key the shell cannot export"
    else
        fail "the ${mechanism} loader check accepted a key the shell cannot export" \
            "loader_problems is not asserting anything about the file it is handed"
    fi
done

# A quoted spaced value survives sourcing and does not survive the export idiom,
# which word-splits after xargs strips the quotes. The template has no spaced
# value today, so the difference is proved on a fixture rather than trusted.
spaces_copy="${WORKDIR}/spaces-template"
{
    printf '%s="%s"\n' "${template_keys[0]}" "value with a space"
    printf '%s=\n' "${template_keys[@]:1}"
} >"$spaces_copy"
if [ -z "$(loader_problems source "$spaces_copy")" ]; then
    ok "sourcing keeps a quoted spaced value intact"
else
    fail "sourcing could not load a quoted spaced value that bash itself accepts" \
        "file: ${spaces_copy#"${WORKDIR}/"}" \
        "$(loader_problems source "$spaces_copy")"
fi
if [ -n "$(loader_problems export "$spaces_copy")" ]; then
    ok "the export idiom is caught truncating a spaced value"
else
    fail "the export idiom silently truncated a spaced value and nothing noticed" \
        "the value comparison in the loader child is decoration"
fi

# ---------------------------------------------------------------------------
# The validator's decision logic. Each case states the exit code it demands, so a
# validator that always returns 0 fails here.
# ---------------------------------------------------------------------------
run_validator() {
    local config="$1"
    shift
    local status=0
    if (cd "$REPO_ROOT" && "$VALIDATOR" --config-file "$config" "$@") \
        >"${WORKDIR}/out" 2>&1; then
        status=0
    else
        status=$?
    fi
    cat "${WORKDIR}/out"
    return "$status"
}

good_fixture="${WORKDIR}/good.env"
{
    for var in "${required_vars[@]}"; do
        printf '%s=YOUR_%s_HERE\n' "$var" "$var"
    done
    printf 'DOMAIN_BASE=example.com\n'
} >"$good_fixture"

status=0
out="$(run_validator "$good_fixture" --template --allowlist "$ALLOWLIST")" || status=$?
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -q 'Template validation complete'; then
    ok "validate_config.sh accepts a template that declares every required key"
else
    fail "validate_config.sh rejected a well-formed template (exit ${status})" \
        "output: ${out}"
fi

missing_fixture="${WORKDIR}/missing.env"
grep -v "^${required_vars[0]}=" "$good_fixture" >"$missing_fixture"
status=0
out="$(run_validator "$missing_fixture" --template --allowlist "$ALLOWLIST")" || status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qi 'required key(s) missing'; then
    ok "validate_config.sh rejects a template missing a required key (exit ${status})"
else
    fail "validate_config.sh accepted a template with a required key removed (exit ${status})" \
        "removing ${required_vars[0]} must fail the lane" \
        "output: ${out}"
fi

secret_fixture="${WORKDIR}/secret.env"
{
    for var in "${required_vars[@]}"; do
        if [ "$var" = "${required_vars[0]}" ]; then
            printf '%s=%s\n' "$var" "${planted_head}${planted_mid}${planted_body}"
        else
            printf '%s=YOUR_%s_HERE\n' "$var" "$var"
        fi
    done
} >"$secret_fixture"
status=0
out="$(run_validator "$secret_fixture" --template --allowlist "$ALLOWLIST")" || status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qi 'credential-shaped values'; then
    ok "validate_config.sh rejects a credential-shaped value in the template (exit ${status})"
else
    fail "validate_config.sh accepted a credential-shaped value in the template (exit ${status})" \
        "a committed credential in the template must fail the lane" \
        "output: ${out}"
fi

status=0
out="$(run_validator "$good_fixture" --nonsense-flag)" || status=$?
if [ "$status" -eq 2 ] && printf '%s' "$out" | grep -q 'Unknown argument'; then
    ok "validate_config.sh rejects an unknown argument with usage (exit 2)"
else
    fail "validate_config.sh did not reject an unknown argument (exit ${status})" \
        "expected exit 2 and a usage line" \
        "output: ${out}"
fi

status=0
out="$(run_validator "${WORKDIR}/no-such-file.env" --template --allowlist "$ALLOWLIST")" || status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -q 'not found'; then
    ok "validate_config.sh fails when the config file is missing (exit ${status})"
else
    fail "validate_config.sh did not fail on a missing config file (exit ${status})" \
        "a validator that shrugs at a missing file validates nothing" \
        "output: ${out}"
fi

# Outside template mode the file holds real secrets, so its mode is enforced.
perms_fixture="${WORKDIR}/perms.env"
cp "$good_fixture" "$perms_fixture"
chmod 600 "$perms_fixture"
status=0
out="$(run_validator "$perms_fixture")" || status=$?
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -q 'secure permissions'; then
    ok "validate_config.sh accepts a secrets file at mode 600"
else
    fail "validate_config.sh rejected a secrets file at mode 600 (exit ${status})" \
        "output: ${out}"
fi
chmod 644 "$perms_fixture"
status=0
out="$(run_validator "$perms_fixture")" || status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -q 'too permissive'; then
    ok "validate_config.sh rejects a world-readable secrets file (exit ${status})"
else
    fail "validate_config.sh accepted a world-readable secrets file (exit ${status})" \
        "mode 600 is a stated invariant, and an operator can leave the file readable" \
        "output: ${out}"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} environment-variable assertion(s) failed" >&2
    exit 1
fi

echo "SUCCESS: the template declares, loads, and keeps as placeholders everything" \
    "validate_config.sh requires, and the validator rejects each broken fixture"
