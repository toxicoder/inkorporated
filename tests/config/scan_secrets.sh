#!/bin/bash
# Secret scanner for every file git tracks. Three halves, and all of them have
# to pass: the detector is proved against credentials planted in a temp
# directory; the ledger is proved to silence a finding it covers and to fail on
# an entry that carries no reason or matches nothing; and the tracked-tree scan
# is proved against a throwaway git repository, so the lane cannot pass by
# having found nothing.
#
# Run it with: bazelisk test //tests/config:config_security_scan
#
# A finding is reported as path:line plus the pattern name, never as the matched
# text, so no secret value can reach a test log. Only git-tracked files are read:
# the operator's local secrets file is gitignored and outside this lane, which
# is //:validate_config's job. Patterns are matched with grep -I, so binary files
# are skipped rather than reported.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
ALLOWLIST="${REPO_ROOT}/tools/bazel/secrets-allowlist.txt"
SCAN_ROOT="$REPO_ROOT"
TARGET="bazelisk test //tests/config:config_security_scan"

while [ $# -gt 0 ]; do
    case "$1" in
        --allowlist)
            [ $# -ge 2 ] || { echo "FAIL - --allowlist needs a path" >&2; exit 2; }
            ALLOWLIST="$2"
            shift 2
            ;;
        --scan-root)
            [ $# -ge 2 ] || { echo "FAIL - --scan-root needs a path" >&2; exit 2; }
            SCAN_ROOT="$2"
            shift 2
            ;;
        *)
            echo "Usage: scan_secrets.sh [--allowlist PATH] [--scan-root DIR]" >&2
            exit 2
            ;;
    esac
done

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

require_tool git "apt-get install -y git"
require_tool grep "apt-get install -y grep"
require_tool sed "apt-get install -y sed"

if [ ! -f "$ALLOWLIST" ]; then
    echo "FAIL - expected file is missing: ${ALLOWLIST}" >&2
    echo "       re-run with: ${TARGET}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# The patterns. Each entry is one credential shape a committed file must never
# carry; only the name is ever printed.
# ---------------------------------------------------------------------------
PATTERN_NAMES=(
    "PEM private key header"
    "AWS access key id"
    "GitHub token"
    "Slack token"
    "Google API key"
    "JWT-shaped triple"
)
PATTERN_RES=(
    '-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----'
    'AKIA[0-9A-Z]{16}'
    'gh[pousr]_[0-9A-Za-z]{20,}'
    'xox[baprs]-[0-9A-Za-z_-]{10,}'
    'AIza[0-9A-Za-z_-]{35}'
    'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'
)

combined=""
for re in "${PATTERN_RES[@]}"; do
    combined="${combined:+${combined}|}${re}"
done

# scan_files <strip-prefix> <path>... : one TAB-separated finding per matching
# line, as `relative-path<TAB>line<TAB>pattern name`.
scan_files() {
    local strip="$1"
    shift
    local file hits hit lineno line idx re name count
    for file in "$@"; do
        if [ ! -r "$file" ]; then
            printf '%s\t0\t%s\n' "${file#"$strip"}" "unreadable file"
            continue
        fi
        hits="$(grep -InE -e "$combined" -- "$file" 2>/dev/null | head -40 || true)"
        [ -n "$hits" ] || continue
        count="$(printf '%s\n' "$hits" | grep -c . || true)"
        if [ "$count" -ge 40 ]; then
            printf '%s\t40\t%s\n' "${file#"$strip"}" "match list truncated at 40 lines"
        fi
        while IFS= read -r hit; do
            [ -n "$hit" ] || continue
            lineno="${hit%%:*}"
            line="${hit#*:}"
            for idx in "${!PATTERN_RES[@]}"; do
                re="${PATTERN_RES[$idx]}"
                name="${PATTERN_NAMES[$idx]}"
                if grep -Eqe "$re" <<<"$line"; then
                    printf '%s\t%s\t%s\n' "${file#"$strip"}" "$lineno" "$name"
                fi
            done
        done <<<"$hits"
    done
    return 0
}

# ---------------------------------------------------------------------------
# The ledger, read the way tools/bazel/owned_files_check.py reads its ledgers:
# `pattern<TAB>reason` (two spaces work too), blanks and # comments ignored,
# `*` and `?` as globs, an entry with no reason is an error, and an entry that
# matches no scanned file is stale.
# ---------------------------------------------------------------------------
ALLOW_PATTERNS=()
ALLOW_REASONS=()
ALLOW_HITS=()
LEDGER_ERRORS=""

read_ledger() {
    local path="$1" pattern reason
    ALLOW_PATTERNS=()
    ALLOW_REASONS=()
    ALLOW_HITS=()
    LEDGER_ERRORS=""
    while IFS=$'\t' read -r pattern reason || [ -n "$pattern" ]; do
        [ -n "$pattern" ] || continue
        if [ -z "${reason//[[:space:]]/}" ]; then
            LEDGER_ERRORS="${LEDGER_ERRORS}the allowlist entry '${pattern}' carries no reason"$'\n'
            continue
        fi
        ALLOW_PATTERNS+=("$pattern")
        ALLOW_REASONS+=("$reason")
        ALLOW_HITS+=(0)
    done < <(sed -e 's/[[:space:]]*$//' -e 's/\t\{1,\}/\t/g' -e 's/  \{1,\}/\t/g' \
                  -e 's/^\t*//' "$path" \
                | grep -vE '^[[:space:]]*(#|$)' || true)
    return 0
}

# ledger_covers <relative-path> : succeed when an entry covers it, and record
# that the entry did. The right-hand side stays unquoted so the ledger entry is
# read as a glob, which is what the ledger documents.
ledger_covers() {
    local path="$1" idx
    for idx in "${!ALLOW_PATTERNS[@]}"; do
        # shellcheck disable=SC2053  # glob match is the point here
        if [[ "$path" == ${ALLOW_PATTERNS[$idx]} ]]; then
            ALLOW_HITS[idx]=1
            return 0
        fi
    done
    return 1
}

# ledger_mark_paths <relative-path>... : record which entries cover the scanned
# tree, whether or not those files carry a finding. This is what makes a stale
# entry visible.
ledger_mark_paths() {
    local path
    for path in "$@"; do
        ledger_covers "$path" || true
    done
    return 0
}

stale_entries() {
    local idx out=""
    for idx in "${!ALLOW_HITS[@]}"; do
        if [ "${ALLOW_HITS[idx]}" != "1" ]; then
            out="${out} ${ALLOW_PATTERNS[$idx]}"
        fi
    done
    printf '%s' "$out"
}

# collect_unallowed <findings-blob> : split findings into ledger-explained and
# not. Sets UNALLOWED (newline-separated) and ALLOWED_COUNT.
UNALLOWED=""
ALLOWED_COUNT=0
collect_unallowed() {
    local findings="$1" path lineno name
    UNALLOWED=""
    ALLOWED_COUNT=0
    while IFS=$'\t' read -r path lineno name; do
        [ -n "$path" ] || continue
        if ledger_covers "$path"; then
            ALLOWED_COUNT=$((ALLOWED_COUNT + 1))
        else
            UNALLOWED="${UNALLOWED}${path}:${lineno}: ${name}"$'\n'
        fi
    done <<<"$findings"
    return 0
}

line_count() {
    local blob="$1"
    if [ -z "$blob" ]; then
        printf '0'
    else
        printf '%s' "$(printf '%s\n' "$blob" | grep -c . || true)"
    fi
}

# scan_tree <root> : the tracked-tree half, reusable against any git checkout so
# the failure path can be exercised without writing into the real one. Sets
# UNALLOWED, ALLOWED_COUNT, TRACKED_COUNT, LEDGER_ERRORS.
scan_tree() {
    local root="$1" path
    TRACKED_COUNT=0
    tracked=()
    mapfile -d '' -t tracked < <(git -C "$root" ls-files -z)
    TRACKED_COUNT="${#tracked[@]}"
    if [ "${#tracked[@]}" -eq 0 ]; then
        UNALLOWED=""
        ALLOWED_COUNT=0
        return 0
    fi
    scan_targets=()
    for path in "${tracked[@]}"; do
        scan_targets+=("${root}/${path}")
    done
    ledger_mark_paths "${tracked[@]}"
    collect_unallowed "$(scan_files "${root}/" "${scan_targets[@]}")"
    return 0
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---------------------------------------------------------------------------
# Half one: plant every credential shape the scanner claims to know about in a
# temp fixture directory and require the detector to find each one. Nothing is
# written into the checkout. Each planted value is assembled from parts so the
# scanner's own source never holds a string its patterns would match.
# ---------------------------------------------------------------------------
FIXTURE="${WORKDIR}/fixture"
mkdir -p "$FIXTURE"

pem_head='-----BEGIN '
pem_tail='PRIVATE KEY-----'
aws_head='AKIA'
aws_body='ABCDEFGHIJKLMNOP'
gh_head='gh'
gh_mid='s_'
gh_body='0123456789abcdefABCDEF0123456789'
slack_head='xox'
slack_mid='b-'
slack_body='123456789012-ABCDEFGHabcdef'
google_head='AIza'
google_body='0123456789abcdefABCDEF_-012345678901234'
jwt_head='eyJ'
jwt_a='hbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
jwt_b='eyJzdWIiOiIxMjM0NTY3ODkwIn0'
jwt_c='dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'

{
    printf '%sRSA %s\n' "$pem_head" "$pem_tail"
    printf '%s\n' 'MIIEowIBAAKCAQEA0Z3N6m1l3Fh0u0n1Q7t0V1gG1o6o6p1Q'
    printf '%s\n' 'Z3VhcmQgYm9keSBsaW5lIHVzZWQgYnkgdGhlIGZpeHR1cmU'
    printf -- '-----END RSA %s\n' "$pem_tail"
} >"${FIXTURE}/id_rsa"
printf 'aws_access_key_id = %s%s\n' "$aws_head" "$aws_body" >"${FIXTURE}/aws.ini"
printf 'token: %s%s%s\n' "$gh_head" "$gh_mid" "$gh_body" >"${FIXTURE}/github.yaml"
printf 'SLACK_TOKEN=%s%s\n' "$slack_head" "${slack_mid}${slack_body}" >"${FIXTURE}/slack.env"
printf 'google_api_key: %s%s\n' "$google_head" "$google_body" >"${FIXTURE}/google.yaml"
printf 'authorization: Bearer %s%s.%s.%s\n' \
    "$jwt_head" "$jwt_a" "$jwt_b" "$jwt_c" >"${FIXTURE}/jwt.txt"
printf '%s\n' 'nothing here is a credential: name=dashboard replicas=3' \
    'base: dev.example.com image=registry.example.com/dashboard:1.0.0' \
    >"${FIXTURE}/clean.yaml"

# Which fixture file must trip which pattern, by pattern index.
FIXTURE_FILES=(id_rsa aws.ini github.yaml slack.env google.yaml jwt.txt)

fixture_findings="$(scan_files "${WORKDIR}/" "${FIXTURE}"/*)"

for idx in "${!PATTERN_NAMES[@]}"; do
    want="${FIXTURE_FILES[$idx]}"
    name="${PATTERN_NAMES[$idx]}"
    if printf '%s\n' "$fixture_findings" \
        | grep -qE "^fixture/${want}"$'\t''[0-9]+'$'\t'"${name}\$"; then
        ok "the detector flags a planted ${name} in fixture/${want}"
    else
        fail "the detector does not flag a planted ${name}" \
            "fixture/${want} carries one and the scan reported:" \
            "${fixture_findings:-<no findings at all>}"
    fi
done

if printf '%s\n' "$fixture_findings" | grep -qE '^fixture/clean'; then
    fail "the detector flags the clean fixture" \
        "a benign config file must produce no finding, got:" \
        "$(printf '%s\n' "$fixture_findings" | grep -E '^fixture/clean')"
else
    ok "the detector leaves the clean fixture alone"
fi

fixture_count="$(line_count "$fixture_findings")"
if [ "$fixture_count" -eq "${#PATTERN_NAMES[@]}" ]; then
    ok "the planted fixtures produce exactly ${#PATTERN_NAMES[@]} finding(s), no cross-matches"
else
    fail "the planted fixtures produced the wrong number of findings" \
        "expected ${#PATTERN_NAMES[@]}, got ${fixture_count}" \
        "$fixture_findings"
fi

# The scanner must not flag its own source, which is where the patterns live.
self_findings="$(scan_files "" "$(readlink -f "$0")")"
if [ -n "$self_findings" ]; then
    fail "the scanner flags its own source" \
        "the planted fixtures are assembled from parts for exactly this reason:" \
        "$self_findings"
else
    ok "the scanner does not flag its own source"
fi

# ---------------------------------------------------------------------------
# Half two: the ledger. Proved against the fixtures, because a ledger nobody
# has seen work is indistinguishable from a ledger that lets everything through.
# ---------------------------------------------------------------------------
LEDGER_DIR="${WORKDIR}/ledger"
mkdir -p "$LEDGER_DIR"
: >"${LEDGER_DIR}/empty.tsv"

fixture_paths=()
for path in "${FIXTURE}"/*; do
    fixture_paths+=("${path#"${WORKDIR}/"}")
done

# No ledger at all: every planted credential must come back as unallowlisted.
read_ledger "${LEDGER_DIR}/empty.tsv"
collect_unallowed "$fixture_findings"
if [ "$(line_count "$UNALLOWED")" -eq "${#PATTERN_NAMES[@]}" ]; then
    ok "with an empty ledger every planted credential is reported, not waved through"
else
    fail "an empty ledger did not report every planted credential" \
        "expected ${#PATTERN_NAMES[@]} unallowlisted finding(s), got $(line_count "$UNALLOWED")" \
        "${UNALLOWED:-<nothing reported>}"
fi

# One entry: the finding it covers goes quiet and the rest stay reported.
printf '%s\t%s\n' 'fixture/aws.ini' 'planted fixture, not a real key' \
    >"${LEDGER_DIR}/one.tsv"
read_ledger "${LEDGER_DIR}/one.tsv"
collect_unallowed "$fixture_findings"
if [ "$ALLOWED_COUNT" -eq 1 ] && ! printf '%s\n' "$UNALLOWED" | grep -q 'aws.ini'; then
    ok "the ledger entry silences exactly the finding it covers"
else
    fail "the ledger did not silence exactly the finding it covers" \
        "allowlisted: ${ALLOWED_COUNT} (expected 1)" \
        "still reported:" "${UNALLOWED:-<nothing>}"
fi
if [ "${ALLOW_HITS[0]:-0}" = "1" ]; then
    ok "the ledger records that its entry matched a scanned file"
else
    fail "the ledger entry that covers the fixture was not recorded as used" \
        "a ledger that cannot report staleness rots silently"
fi

# A glob entry covers a whole tree.
printf '%s\t%s\n' 'fixture/*yaml' 'fixture tree' >"${LEDGER_DIR}/glob.tsv"
read_ledger "${LEDGER_DIR}/glob.tsv"
collect_unallowed "$fixture_findings"
if [ "$ALLOWED_COUNT" -eq 2 ]; then
    ok "a ledger glob covers every finding under it (2 yaml fixtures)"
else
    fail "the ledger glob did not cover the findings under it" \
        "allowlisted: ${ALLOWED_COUNT} (expected 2)" \
        "still reported: ${UNALLOWED:-<nothing>}"
fi

# An entry with no reason is refused, and a stale entry is visible.
printf '%s\n' 'fixture/github.yaml' >"${LEDGER_DIR}/no-reason.tsv"
read_ledger "${LEDGER_DIR}/no-reason.tsv"
if [ -n "$LEDGER_ERRORS" ]; then
    ok "a ledger entry with no reason is rejected: ${LEDGER_ERRORS%%$'\n'*}"
else
    fail "a ledger entry with no reason was accepted" \
        "an unexplained allowlist entry is how a real secret gets waved through"
fi

printf '%s\t%s\n' 'fixture/no-such-file*' 'covers nothing' >"${LEDGER_DIR}/stale.tsv"
read_ledger "${LEDGER_DIR}/stale.tsv"
ledger_mark_paths "${fixture_paths[@]}"
if [ -n "$(stale_entries)" ]; then
    ok "a ledger entry that matches no scanned file is reported as stale:$(stale_entries)"
else
    fail "a ledger entry covering nothing was not reported as stale" \
        "the ledger would be free to accumulate entries nobody needs"
fi

# ---------------------------------------------------------------------------
# Half three: the tracked-tree scan, proved against a throwaway git repository
# before it is pointed at the real checkout. This is the path a committed secret
# has to trip, so it is exercised here rather than assumed.
# ---------------------------------------------------------------------------
GITREPO="${WORKDIR}/gitrepo"
mkdir -p "$GITREPO/secrets"
printf '%s%s\n' "$aws_head" "$aws_body" >"${GITREPO}/secrets/leaked.txt"
printf 'replicas: 3\n' >"${GITREPO}/clean.yaml"
(
    cd "$GITREPO" &&
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git init -q . &&
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git add -A
) >/dev/null 2>&1

read_ledger "${LEDGER_DIR}/empty.tsv"
scan_tree "$GITREPO"
if [ "$TRACKED_COUNT" -eq 2 ] && [ "$(line_count "$UNALLOWED")" -eq 1 ] &&
    printf '%s\n' "$UNALLOWED" | grep -q '^secrets/leaked.txt:1: AWS access key id$'; then
    ok "a committed secret in a tracked tree is reported by the tree scan"
else
    fail "the tree scan did not report a secret committed to a tracked tree" \
        "tracked: ${TRACKED_COUNT} (expected 2)" \
        "unallowlisted: $(line_count "$UNALLOWED") (expected 1)" \
        "${UNALLOWED:-<nothing reported>}"
fi

printf '%s\t%s\n' 'secrets/*' 'throwaway repository, nothing real lives here' \
    >"${LEDGER_DIR}/repo.tsv"
read_ledger "${LEDGER_DIR}/repo.tsv"
scan_tree "$GITREPO"
if [ "$(line_count "$UNALLOWED")" -eq 0 ] && [ "$ALLOWED_COUNT" -eq 1 ] &&
    [ -z "$(stale_entries)" ]; then
    ok "the same committed secret is explained when the ledger covers its tree"
else
    fail "the ledger did not explain the committed secret in the throwaway repository" \
        "allowlisted: ${ALLOWED_COUNT} (expected 1)" \
        "unallowlisted: ${UNALLOWED:-<nothing>}" \
        "stale:$(stale_entries)"
fi

# ---------------------------------------------------------------------------
# The real checkout: every credential shape git tracks, filtered only by the
# ledger the repository ships.
# ---------------------------------------------------------------------------
read_ledger "$ALLOWLIST"
if [ -n "$LEDGER_ERRORS" ]; then
    while IFS= read -r ledger_line; do
        [ -n "$ledger_line" ] || continue
        fail "${ledger_line}" "ledger: ${ALLOWLIST}"
    done <<<"$LEDGER_ERRORS"
fi

scan_tree "$SCAN_ROOT"
if [ "$TRACKED_COUNT" -lt 100 ]; then
    fail "git ls-files under ${SCAN_ROOT} returned only ${TRACKED_COUNT} file(s)" \
        "a scan over almost nothing proves nothing"
else
    ok "scanned ${TRACKED_COUNT} tracked file(s) under ${SCAN_ROOT}"
fi

if [ -n "$UNALLOWED" ]; then
    while IFS= read -r finding; do
        [ -n "$finding" ] || continue
        fail "a credential shape is committed and no ledger entry explains it" \
            "${finding}" \
            "remove and rotate it, or ledger the path with a reason in ${ALLOWLIST}"
    done <<<"$UNALLOWED"
else
    ok "every credential shape in the tracked tree is explained by the ledger"
fi

if [ -n "$(stale_entries)" ]; then
    fail "the allowlist carries entries that match nothing in the tracked tree" \
        "stale patterns:$(stale_entries)" \
        "delete them, or the ledger hides files that no longer need hiding"
else
    ok "every ledger entry still matches a tracked file (${#ALLOW_PATTERNS[@]} entries)"
fi

echo "summary: ${TRACKED_COUNT} tracked file(s) scanned, ${ALLOWED_COUNT} finding(s) \
allowlisted, ${failures} assertion(s) failed"

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} secret-scan assertion(s) failed" >&2
    exit 1
fi

echo "SUCCESS: the detector finds all ${#PATTERN_NAMES[@]} planted credential shapes," \
    "the ledger is honoured and audited, and the tracked tree carries nothing it" \
    "cannot explain"
