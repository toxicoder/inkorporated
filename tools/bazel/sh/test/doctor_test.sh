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

# 5. The bazelisk row is measured against the pin rather than merely "is there
#    a binary called bazelisk". The tree is a scratch checkout and the doctor is
#    pointed at it the way `bazelisk run //:doctor` does, with
#    BUILD_WORKSPACE_DIRECTORY, because that is the only route by which the
#    doctor learns which checkout it is reporting on.
REPO_FROM_TESTS="$(cd "${HERE}/../../../.." && pwd)"
PINNED="$(tr -d '[:space:]' <"${REPO_FROM_TESTS}/.bazelversion")"
[ -n "$PINNED" ] || { echo "FATAL: .bazelversion is empty" >&2; exit 1; }

pin_tree="${WORKDIR}/pinned-checkout"
mkdir -p "${pin_tree}/.git"
cp "${REPO_FROM_TESTS}/.bazelversion" "${pin_tree}/.bazelversion"

# Shadow the whole PATH and then withhold bazelisk, so the report has to say
# "missing" for a reason rather than because the file was never looked for.
nobazel_dir="${WORKDIR}/no-bazelisk/bin"
mkdir -p "$nobazel_dir"
IFS=: read -ra path_dirs <<< "$PATH"
for dir in "${path_dirs[@]}"; do
    [ -d "$dir" ] || continue
    for tool in "${dir}"/*; do
        [ -x "$tool" ] && [ ! -d "$tool" ] || continue
        name="$(basename "$tool")"
        [ "$name" = bazelisk ] && continue
        [ -e "${nobazel_dir}/${name}" ] || ln -s "$tool" "${nobazel_dir}/${name}"
    done
done

status=0
out="$(env -u BAZEL_META_OUTPUT_BASE PATH="$nobazel_dir" \
    BUILD_WORKSPACE_DIRECTORY="$pin_tree" "$DOCTOR" 2>&1)" || status=$?
check "a host without bazelisk exits with the documented failure" \
    "$([ "$status" -eq 1 ] && echo 0 || echo "1 (exit ${status})")"
status=0
printf '%s\n' "$out" | grep -q "MISMATCH" || status=$?
check "text mode calls the absent bazelisk a mismatch, not a pass" "$status"
status=0
printf '%s\n' "$out" | grep -q "\.bazelversion pins ${PINNED}" || status=$?
check "the mismatch line names the version .bazelversion pins" "$status"

status=0
json="$(env PATH="$nobazel_dir" BUILD_WORKSPACE_DIRECTORY="$pin_tree" \
    "$DOCTOR" --json 2>/dev/null)" || true
printf '%s\n' "$json" | python3 -c '
import json, sys
pinned = sys.argv[1]
report = json.loads(sys.stdin.read())
rows = [row for row in report["tools"] if row["tool"] == "bazelisk"]
assert rows, "the census dropped bazelisk entirely"
assert rows[0]["status"] == "MISSING", rows[0]
assert pinned in rows[0]["needed_by"], rows[0]
' "$PINNED" >/dev/null 2>&1 || status=$?
check "--json reports the bazelisk row MISSING and names the pin" "$status"

# 6. A bazelisk that is present but not the pinned one is the same failure: a
#    stale binary builds with a Bazel the repository never chose.
wrong_dir="${WORKDIR}/wrong-bazelisk/bin"
mkdir -p "$wrong_dir"
cat >"${wrong_dir}/bazelisk" <<'FAKE'
#!/usr/bin/env bash
printf 'bazel %s\n' "0.0.0-not-the-pin"
FAKE
chmod +x "${wrong_dir}/bazelisk"
status=0
out="$(env PATH="${wrong_dir}:${PATH}" BUILD_WORKSPACE_DIRECTORY="$pin_tree" \
    "$DOCTOR" 2>&1)" || status=$?
check "a bazelisk off the pin exits with the documented failure" \
    "$([ "$status" -eq 1 ] && echo 0 || echo "1 (exit ${status})")"
status=0
printf '%s\n' "$out" | grep -q "MISMATCH.*\.bazelversion pins ${PINNED}" || status=$?
check "the MISMATCH line names the pinned version, not the stale one" "$status"
status=0
if printf '%s\n' "$out" | grep -q '0\.0\.0-not-the-pin'; then
    status=1
fi
check "the stale version is not passed off as the report" "$status"

# 7. The control: the same tree, the same harness, a bazelisk that does answer
#    with the pinned version, and the doctor says present and exits 0. Without
#    it the two cases above could be reached by a report that only ever says
#    MISMATCH.
right_dir="${WORKDIR}/right-bazelisk/bin"
mkdir -p "$right_dir"
cat >"${right_dir}/bazelisk" <<FAKE
#!/usr/bin/env bash
printf 'bazel %s\n' "${PINNED}"
FAKE
chmod +x "${right_dir}/bazelisk"
status=0
out="$(env PATH="${right_dir}:${PATH}" BUILD_WORKSPACE_DIRECTORY="$pin_tree" \
    "$DOCTOR" 2>&1)" || status=$?
check "a bazelisk on the pin exits 0" "$status"
status=0
printf '%s\n' "$out" | grep -q "bazelisk.*present" || status=$?
check "text mode marks the pinned bazelisk present" "$status"

# 8. The .devcontainer/.env row is the mode of the real file, read from the
#    tree the doctor was pointed at. The file is a scratch fixture with a
#    placeholder value in a temporary directory: the repository's own
#    .devcontainer/.env is never read, copied, or printed.
env_tree="${WORKDIR}/env-checkout"
mkdir -p "${env_tree}/.git" "${env_tree}/.devcontainer"
printf 'DOCTOR_TEST_PLACEHOLDER=scratch-only\n' >"${env_tree}/.devcontainer/.env"
chmod 600 "${env_tree}/.devcontainer/.env"
status=0
[ "$(stat -c '%a' "${env_tree}/.devcontainer/.env")" = "600" ] || status=$?
check "the scratch fixture really is mode 600" "$status"

json="$(env BUILD_WORKSPACE_DIRECTORY="$env_tree" "$DOCTOR" --json 2>/dev/null)" || true
status=0
printf '%s\n' "$json" | python3 -c '
import json, sys
report = json.loads(sys.stdin.read())
assert report["devcontainer_env_mode"] == "600", report["devcontainer_env_mode"]
' >/dev/null 2>&1 || status=$?
check "--json reports the 600 mode of .devcontainer/.env" "$status"

status=0
out="$(env BUILD_WORKSPACE_DIRECTORY="$env_tree" "$DOCTOR" 2>&1)" || true
if ! printf '%s\n' "$out" | grep -qE '^  \.devcontainer/\.env +600$'; then
    status=1
fi
check "text mode prints the 600 mode of .devcontainer/.env" "$status"

# 9. And it is really stat: change the file, the report changes with it.
chmod 640 "${env_tree}/.devcontainer/.env"
json="$(env BUILD_WORKSPACE_DIRECTORY="$env_tree" "$DOCTOR" --json 2>/dev/null)" || true
status=0
printf '%s\n' "$json" | python3 -c '
import json, sys
report = json.loads(sys.stdin.read())
assert report["devcontainer_env_mode"] == "640", report["devcontainer_env_mode"]
' >/dev/null 2>&1 || status=$?
check "the reported mode follows the file, so it is a stat and not a constant" "$status"

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} doctor assertion(s) failed" >&2
    exit 1
fi
echo "SUCCESS: //tools/bazel/sh:doctor reports the host honestly"
