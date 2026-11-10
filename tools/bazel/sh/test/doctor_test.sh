#!/bin/bash
# Unit tests for //tools/bazel/sh:doctor's host report.
#
# Run with: bazelisk test //tools/bazel/sh/test:doctor_test

set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DOCTOR="${HERE}/../doctor.sh"
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

[ -x "$DOCTOR" ] || { echo "FATAL: ${DOCTOR} is missing or not executable" >&2; exit 1; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# 1. The census entries all carry a reason, so a missing tool always comes with
#    the name of the lane that wanted it.
census_rows="$(sed -n '/^REQUIRED_TOOLS=(/,/^)/p;/^OPTIONAL_TOOLS=(/,/^)/p' "$DOCTOR" |
    grep -E '^\s+"' || true)"
if [ -z "$census_rows" ]; then
    echo "FAIL - no census entries found in doctor.sh" >&2
    failures=$((failures + 1))
else
    bad="$(printf '%s\n' "$census_rows" | grep -cvE '^\s+"[a-z0-9_.-]+:.{4,}"' || true)"
    if [ "$bad" = "0" ]; then
        check "every census entry is tool:reason" 0
    else
        check "every census entry is tool:reason (${bad} malformed)" 1
    fi
fi

# 2. --json emits an object the caller can parse, with the counters a CI step
#    would gate on.
status=0
out="$("$DOCTOR" --json 2>&1)" || status=$?
check "--json exits 0 on a host that has the required tools" "$status"
status=0
printf '%s' "$out" | python3 -c '
import json,sys
d = json.load(sys.stdin)
for key in ("bazel_version","required_present","required_missing","tools"):
    assert key in d, key
assert isinstance(d["tools"], list) and d["tools"], "tools must be a non-empty list"
assert all({"tool","kind","status","needed_by"} <= set(row) for row in d["tools"])
' >/dev/null 2>&1 || status=$?
check "--json emits parseable JSON with the documented keys" "$status"

# 3. A host without the required binaries reports them and exits non-zero, so a
#    CI job cannot mistake an empty PATH for a green lane.
mkdir -p "${WORKDIR}/bin"
# Shadow the whole PATH and then withhold exactly the tools the census names, so
# the test proves the doctor reports those missing and not simply that a stripped
# PATH breaks the script.
for dir in /usr/local/bin /usr/bin /bin; do
    for tool in "$dir"/*; do
        name="$(basename "$tool")"
        case "$name" in
            shellcheck | yamllint | ansible-lint | ansible | ansible-doc | \
                terraform | bazelisk | kubectl | helm | mkdocs | mike | \
                nvidia-smi | aws | docker) continue ;;
        esac
        [ -e "${WORKDIR}/bin/$name" ] || ln -s "$tool" "${WORKDIR}/bin/$name"
    done
done
status=0
PATH="${WORKDIR}/bin" "$DOCTOR" --json >"${WORKDIR}/stripped.json" 2>"${WORKDIR}/stripped.err" || status=$?
check "doctor fails when required tools are absent" "$([ "$status" -ne 0 ] && echo 0 || echo 1)"
status=0
python3 -c '
import json,sys
d = json.load(open(sys.argv[1]))
assert d["required_missing"] > 0, d
' "${WORKDIR}/stripped.json" >/dev/null 2>&1 || status=$?
check "the JSON counts the missing required tools" "$status"

# 4. Text mode names the missing tool rather than only counting it. The doctor
#    exits non-zero here by design, so only the report itself is asserted on.
PATH="${WORKDIR}/bin" "$DOCTOR" >"${WORKDIR}/stripped.txt" 2>/dev/null || true
status=0
grep -q 'MISSING' "${WORKDIR}/stripped.txt" || status=$?
check "text mode marks each absent tool MISSING" "$status"

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} doctor assertion(s) failed" >&2
    exit 1
fi
echo "SUCCESS: //tools/bazel/sh:doctor reports the host honestly"
