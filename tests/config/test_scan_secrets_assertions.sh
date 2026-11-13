#!/bin/bash
# Unit tests for the assertion shape used by //tests/config:config_security_scan.
#
# Issue #45: that lane went red inside //:gate while the very finding its
# assertion said was missing was printed in the failure text. The cause is the
# shell, not the detector. Under `set -o pipefail` this pipeline reports
# failure even though grep matched:
#
#     printf '%s\n' "$findings" | grep -qE '^fixture/jwt.txt...'
#
# grep -q exits the moment it matches. The writer on the left has more lines
# still queued, its next write hits a closed pipe, and it dies of SIGPIPE with
# status 141. pipefail promotes that 141 to the status of the whole pipeline,
# so the `if` takes the failure branch for a finding that is present. The race
# is real but narrow (measured: 56 of 160,000 trials, every one of them 141),
# which is why it showed up only under the parallel load of the full gate.
#
# The lane now feeds grep from a here-string instead. A here-string is a
# tempfile, not a pipe, so there is no writer process left to signal.
#
# These tests pin both halves: that the vulnerable shape really does fail (so
# this lane cannot silently lose its power), and that the lane uses only the
# safe shape. They fail on the pre-fix source and pass on the fixed one.
#
# Run with: bazelisk test //tests/config:test_scan_secrets_assertions

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Bazel ships the scanner next to this test through the data attribute, so the
# script directory is where it lives under runfiles as well as in the checkout.
SCANNER="${REPO_ROOT}/scan_secrets.sh"
TARGET="bazelisk test //tests/config:test_scan_secrets_assertions"

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

if [ ! -f "$SCANNER" ]; then
    echo "FATAL: ${SCANNER} is missing; the data attribute of" >&2
    echo "       //tests/config:test_scan_secrets_assertions must ship scan_secrets.sh" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---------------------------------------------------------------------------
# The two shapes, one blob.
#
# The blob has to be far larger than the 64 KiB pipe buffer and has to match on
# its first line: that combination is what forces the writer to still be
# blocked on write() when grep walks away, which turns a rare race into a
# certainty. A six-line blob leaves the window open only occasionally, which is
# exactly why the original failure was intermittent.
# ---------------------------------------------------------------------------
MATCH_LINE=$'fixture/jwt.txt\t1\tJWT-shaped triple'
PAD_LINE=$'fixture/filler\t1\tPadding pattern'
{
    printf '%s\n' "$MATCH_LINE"
    for _ in $(seq 1 20000); do
        printf '%s\n' "$PAD_LINE"
    done
} >"${WORKDIR}/blob"
big="$(cat "${WORKDIR}/blob")"
TAB=$'\t'
MATCH_RE='^fixture/jwt\.txt'"${TAB}"'[0-9]+'"${TAB}"'JWT-shaped triple$'

if [ "${#big}" -lt 65536 ]; then
    fail "the probe blob is smaller than the pipe buffer" \
        "size: ${#big} bytes; it must exceed 65536 or the probe below cannot be certain"
else
    ok "the probe blob (${#big} bytes) overflows the 64 KiB pipe buffer"
fi

# ---------------------------------------------------------------------------
# 1. The lane must keep `set -o pipefail`.
# Dropping pipefail would also make the old pipeline pass, and would do it by
# hiding every other real pipeline failure in the file, so it is not a fix.
# ---------------------------------------------------------------------------
if grep -qE '^[[:space:]]*set[[:space:]]+-[a-z]*o[[:space:]]+pipefail' <<<"$(cat "$SCANNER")"; then
    ok "the scanner still runs under set -o pipefail"
else
    fail "the scanner no longer sets pipefail" \
        "dropping pipefail would mask this race by masking every pipeline failure"
fi

# ---------------------------------------------------------------------------
# 2. The vulnerable shape has to still be detected as broken.
# This is the control: if the pipeline below ever reports success, the machine
# or the test has changed and the rest of this lane proves nothing.
# ---------------------------------------------------------------------------
vulnerable_failures=0
vulnerable_statuses=""
for _ in $(seq 1 200); do
    status=0
    printf '%s\n' "$big" | grep -qE "$MATCH_RE" || status=$?
    if [ "$status" -eq 0 ]; then
        vulnerable_failures=$((vulnerable_failures + 1))
    else
        vulnerable_statuses="$status"
    fi
done
if [ "$vulnerable_failures" -eq 0 ] && [ "$vulnerable_statuses" != "0" ]; then
    ok "the piped grep -q shape still misreports a match (last status ${vulnerable_statuses})"
else
    fail "the piped grep -q probe no longer reproduces the race" \
        "${vulnerable_failures} of 200 trials reported success" \
        "this lane has lost its power to guard //tests/config:config_security_scan"
fi

# ---------------------------------------------------------------------------
# 3. The here-string shape must report the match every time.
# Same blob, same pattern, same shell options: only the redirection differs.
# ---------------------------------------------------------------------------
here_failures=0
here_statuses=""
for _ in $(seq 1 200); do
    status=0
    grep -qE "$MATCH_RE" <<<"$big" || status=$?
    if [ "$status" -ne 0 ]; then
        here_failures=$((here_failures + 1))
        here_statuses="$status"
    fi
done
if [ "$here_failures" -eq 0 ]; then
    ok "the here-string shape reports the match in 200 of 200 trials"
else
    fail "the here-string shape lost a match" \
        "${here_failures} of 200 trials exited ${here_statuses}" \
        "the assertion that replaced the pipe is not sound either"
fi

# ---------------------------------------------------------------------------
# 4. The negative control.
# Without this, the two probes above could both be reporting success for an
# unrelated reason (a broken MATCH_RE, a grep that always exits 0) and the lane
# would still look green. A pattern that matches nothing has to exit 1.
# ---------------------------------------------------------------------------
status=0
printf '%s\n' "$big" | grep -qE 'never-matches-any-line' || status=$?
if [ "$status" -eq 1 ]; then
    ok "a non-matching grep -q still exits 1, so the probes above are not passing by accident"
else
    fail "a non-matching grep -q exited ${status}, expected 1" \
        "the control and the fix cannot be told apart"
fi

# ---------------------------------------------------------------------------
# 5. The lane must not feed an early-exiting consumer from a builtin.
# This is the regression net: it fails the moment any assertion in the scanner
# goes back to `printf ... | grep -q ...` or `echo ... | head ...`. Comment
# lines are skipped, since the file documents the race in prose.
# ---------------------------------------------------------------------------
# Written without awk and without backslash escapes on purpose. awk folds the
# escapes in a -v assignment, and gawk drops the one in `\|` where mawk keeps
# it; the collapsed form reads the pipe as an alternation and its first branch
# then matches every `echo` and `printf` line in the file, which is how this
# guard once failed CI over lines 27, 32, 53, 64, 75 and 513. A bracket
# expression and POSIX classes carry the same meaning in every shell.
VULNERABLE_SHAPE='(printf|echo)[^|]*[|][[:space:]]*(grep[[:space:]]+-[[:alpha:]]*q|head([^[:alpha:]]|$))'
# Continuations are folded first: the assertion that went red in issue #45
# breaks the line between the writer and the pipe, so a line-at-a-time scan
# would walk straight past it.
offenders=""
line_no=0
folded=""
fold_start=0
probe=""
while IFS= read -r raw || [ -n "$raw" ]; do
    line_no=$((line_no + 1))
    if [ -z "$folded" ]; then
        fold_start=$line_no
        folded=$raw
    else
        folded="${folded} ${raw}"
    fi
    case $folded in
        *\\) continue ;;
    esac
    probe="${folded#"${folded%%[![:space:]]*}"}"
    if [ "${probe:0:1}" != '#' ] && [[ $folded =~ $VULNERABLE_SHAPE ]]; then
        offenders="${offenders}${fold_start}:${folded}"$'\n'
    fi
    folded=""
done < "$SCANNER"
offenders="${offenders%$'\n'}"
if [ -z "$offenders" ]; then
    ok "no assertion in the scanner pipes a builtin into grep -q or head"
else
    fail "the scanner pipes a builtin into an early-exiting consumer" \
        "under pipefail a SIGPIPE writer turns a match into a failure (issue #45)" \
        "feed the data to grep with a here-string instead:" \
        "$offenders"
fi

# ---------------------------------------------------------------------------
# 6. Under load, where the race actually appeared.
# The gate runs thirty-odd targets at once; this lane reproduces that pressure
# on the scanner's own assertions. The here-string cannot lose a match, so any
# failure here is the bug coming back.
# ---------------------------------------------------------------------------
load_pids=()
cpus="$(nproc 2>/dev/null || printf '4')"
for _ in $(seq 1 "$cpus"); do
    timeout 120 bash -c 'while :; do :; done' &
    load_pids+=("$!")
done
stop_load() {
    local pid
    for pid in ${load_pids[@]+"${load_pids[@]}"}; do
        kill "$pid" 2>/dev/null || true
    done
    load_pids=()
}
trap 'stop_load; rm -rf "$WORKDIR"' EXIT

# A wall-clock budget, not a trial count: the loop has to stay cheap under the
# busiest gate run, and a fixed count would make this lane's own runtime
# depend on how loaded the machine already is.
LOAD_BUDGET_SECS=5
load_end=$((SECONDS + LOAD_BUDGET_SECS))
races=0
trials=0
while [ "$SECONDS" -lt "$load_end" ]; do
    status=0
    grep -qE "$MATCH_RE" <<<"$MATCH_LINE"$'\n'"$PAD_LINE" || status=$?
    [ "$status" -eq 0 ] || races=$((races + 1))
    trials=$((trials + 1))
done
if [ "$trials" -lt 200 ]; then
    fail "the loaded probe only managed ${trials} trial(s) in ${LOAD_BUDGET_SECS}s" \
        "the shape was never exercised; the machine is too busy to judge"
elif [ "$races" -eq 0 ]; then
    ok "${trials} loaded trials of the shipped assertion shape all matched"
else
    fail "${races} of ${trials} loaded trials lost a match" \
        "the assertion race from issue #45 is back in the scanner"
fi

stop_load

echo "summary: ${failures} assertion(s) failed"

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} scanner-assertion assertion(s) failed" >&2
    exit 1
fi

echo "SUCCESS: the scanner's assertions are written in the race-free shape"
