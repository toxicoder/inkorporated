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
        # The doctor's own report is what names the tool the assertion tripped
        # over; without it a sandbox-only failure has nothing to read.
        if [ -n "${out:-}" ]; then
            printf '%s\n' "$out" | sed 's/^/    | /' >&2
        fi
        failures=$((failures + 1))
    fi
}

# shadow_path_dir <dir> <dst> links every entry of one PATH directory into
# <dst>. One ln call per directory is the point: a Bazel test action is handed a
# PATH with a few thousand entries on a runner, and one ln per entry spent the
# target's whole timeout building the farm before it asserted anything. The -f
# replaces a dangling link an earlier directory left behind, which test -e alone
# reads as absent while ln still refuses the name, so the tool that directory
# really has stays shadowed -- the shape that made a census test report a tool
# the host has. Callers walk PATH in reverse so a shared name keeps the copy a
# real PATH would have found first.
shadow_path_dir() {
    local dir="$1" dst="$2" candidate
    local -a entries=()
    shopt -s nullglob
    for candidate in "${dir}"/*; do
        [ -e "$candidate" ] || [ -L "$candidate" ] || continue
        entries+=("$candidate")
    done
    shopt -u nullglob
    [ "${#entries[@]}" -eq 0 ] && return 0
    ln -sft "$dst" "${entries[@]}"
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

# 1b. shadow_path_dir replaces a dangling link instead of tripping over it. This
#     is the shape that failed on a runner whose PATH had the same tool name in
#     two directories: the guard saw no file, ln refused the existing link, and
#     the tool the second directory really has was never reachable.
stub_root="${WORKDIR}/stub-dirs"
mkdir -p "${stub_root}/first" "${stub_root}/second" "${stub_root}/libexec"
printf '#!/bin/sh\necho first\n' >"${stub_root}/libexec/gate_stub_tool"
chmod +x "${stub_root}/libexec/gate_stub_tool"
shadow_path_dir "${stub_root}/libexec" "${stub_root}/first"
rm -f "${stub_root}/libexec/gate_stub_tool"
printf '#!/bin/sh\necho second\n' >"${stub_root}/second/gate_stub_tool"
chmod +x "${stub_root}/second/gate_stub_tool"
status=0
shadow_path_dir "${stub_root}/second" "${stub_root}/first" || status=$?
check "a dangling link does not make the shadow PATH fail to add a tool" "$status"
status=0
[ "$("${stub_root}/first/gate_stub_tool" 2>/dev/null || true)" = "second" ] ||
    status=1
check "the shadow PATH runs the tool the second directory has" "$status"

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
withheld=(shellcheck yamllint ansible-lint ansible ansible-doc terraform
    bazelisk kubectl helm node npm nvidia-smi aws docker)
for dir in /bin /usr/bin /usr/local/bin; do
    shadow_path_dir "$dir" "${WORKDIR}/bin"
done
for name in "${withheld[@]}"; do
    rm -f "${WORKDIR}/bin/${name}"
done
# The farm has to be a usable PATH, or the next three assertions would only
# prove that the doctor cannot run at all.
status=0
{ [ -x "${WORKDIR}/bin/git" ] && [ ! -e "${WORKDIR}/bin/terraform" ]; } || status=1
check "the shadow farm still runs git and withholds terraform" "$status"
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
for ((idx=${#path_dirs[@]} - 1; idx >= 0; idx--)); do
    dir="${path_dirs[idx]}"
    [ -d "$dir" ] || continue
    shadow_path_dir "$dir" "$nobazel_dir"
done
rm -f "${nobazel_dir}/bazelisk"

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

# 10. The two docs rows are the state of the tree the doctor was pointed at, in
#     both directions: the python venv the page generators import, and the npm
#     tree the Fumadocs export runs from. Without a fixture for each branch the
#     coverage lane only reaches its floor on a host that happens to have run
#     //docs:setup-docs, which is a property of the machine and not of this
#     script, and a clean CI runner would lose the row it never executed.
venv_tree="${WORKDIR}/venv-checkout"
mkdir -p "${venv_tree}/.git" "${venv_tree}/.venv-docs/bin"
mkdir -p "${venv_tree}/docs-site/node_modules/.bin"
: >"${venv_tree}/.venv-docs/bin/python"
chmod +x "${venv_tree}/.venv-docs/bin/python"
: >"${venv_tree}/docs-site/node_modules/.bin/next"
chmod +x "${venv_tree}/docs-site/node_modules/.bin/next"
json="$(env BUILD_WORKSPACE_DIRECTORY="$venv_tree" "$DOCTOR" --json 2>/dev/null)" || true
status=0
printf '%s\n' "$json" | python3 -c '
import json, sys
report = json.loads(sys.stdin.read())
assert report["docs_venv"] == "ready", report["docs_venv"]
assert report["docs_site_install"] == "ready", report["docs_site_install"]
' >/dev/null 2>&1 || status=$?
check "--json reports both docs trees ready when the checkout has them" "$status"

status=0
out="$(env BUILD_WORKSPACE_DIRECTORY="$venv_tree" "$DOCTOR" 2>&1)" || true
if ! printf '%s\n' "$out" | grep -qE '^  docs-site install +ready$'; then
    status=1
fi
check "text mode prints the docs-site install row of the tree it was pointed at" "$status"

json="$(env BUILD_WORKSPACE_DIRECTORY="$env_tree" "$DOCTOR" --json 2>/dev/null)" || true
status=0
printf '%s\n' "$json" | python3 -c '
import json, sys
report = json.loads(sys.stdin.read())
assert report["docs_venv"] != "ready", report["docs_venv"]
assert report["docs_site_install"] != "ready", report["docs_site_install"]
' >/dev/null 2>&1 || status=$?
check "--json says both docs trees are missing when the checkout has neither" "$status"

# 11. A required binary that is on PATH and cannot run is BROKEN, not present.
#     This is the shape a runner produced when pip put the linters in the job's
#     home directory: command -v found the name, the action's throwaway home hid
#     the modules behind it, the lane died with ModuleNotFoundError, and the
#     census had just said every required tool was present.
broken_dir="${WORKDIR}/broken-bin"
mkdir -p "$broken_dir"
for dir in /bin /usr/bin /usr/local/bin; do
    shadow_path_dir "$dir" "$broken_dir"
done
rm -f "${broken_dir}/yamllint"
printf '#!/bin/sh\nexit 3\n' >"${broken_dir}/yamllint"
chmod +x "${broken_dir}/yamllint"
status=0
out="$(env -u BAZEL_META_OUTPUT_BASE PATH="$broken_dir" "$DOCTOR" 2>&1)" || status=$?
check "a required tool that cannot run fails the doctor" \
    "$([ "$status" -eq 1 ] && echo 0 || echo "1 (exit ${status})")"
status=0
printf '%s\n' "$out" | grep -q "yamllint.*BROKEN" || status=$?
check "text mode names the unrunnable tool BROKEN, not present" "$status"
status=0
printf '%s\n' "$out" | grep -q "lint-requirements.txt" || status=$?
check "the report names the pinned requirements for a broken tool" "$status"
status=0
json="$(env -u BAZEL_META_OUTPUT_BASE PATH="$broken_dir" "$DOCTOR" --json 2>/dev/null)" || true
printf '%s\n' "$json" | python3 -c '
import json, sys
report = json.loads(sys.stdin.read())
rows = [row for row in report["tools"] if row["tool"] == "yamllint"]
assert rows, "the census dropped yamllint"
assert rows[0]["status"] == "BROKEN", rows[0]
assert report["required_broken"] >= 1, report
' >/dev/null 2>&1 || status=$?
check "--json counts the broken tool and names its status" "$status"

# 12. A tool that runs but sits below the version floor the lane pins is
#     MISMATCH, not present: the name resolves and answers --version, so the
#     gate finds it and then dies inside the Next export in docs-site/, which
#     reports an older node as a syntax error nobody traces back to the host.
#     node is an optional row, so the report says MISMATCH and the doctor still
#     exits 0: the hermetic gate does not need node, and CI's docs lane is the
#     one that cannot run without it.
old_dir="${WORKDIR}/old-node/bin"
mkdir -p "$old_dir"
for dir in /bin /usr/bin /usr/local/bin; do
    shadow_path_dir "$dir" "$old_dir"
done
cat >"${old_dir}/node" <<'FAKE'
#!/bin/sh
echo 'v20.19.0'
FAKE
chmod +x "${old_dir}/node"
status=0
out="$(env -u BAZEL_META_OUTPUT_BASE PATH="$old_dir" "$DOCTOR" 2>&1)" || status=$?
check "a stale optional node leaves the doctor green" \
    "$([ "$status" -eq 0 ] && echo 0 || echo "1 (exit ${status})")"
status=0
printf '%s\n' "$out" | grep -q "node.*MISMATCH" || status=$?
check "text mode names the stale node MISMATCH, not present" "$status"
status=0
printf '%s\n' "$out" | grep -q "found 20, needs 22 or newer" || status=$?
check "the MISMATCH line names the version found and the floor it missed" "$status"
status=0
json="$(env -u BAZEL_META_OUTPUT_BASE PATH="$old_dir" "$DOCTOR" --json 2>/dev/null)" || true
printf '%s\n' "$json" | python3 -c '
import json, sys
report = json.loads(sys.stdin.read())
rows = [row for row in report["tools"] if row["tool"] == "node"]
assert rows, "the census dropped node"
assert rows[0]["status"] == "MISMATCH", rows[0]
assert rows[0]["kind"] == "optional", rows[0]
assert report["required_missing"] == 0, report
' >/dev/null 2>&1 || status=$?
check "--json calls the stale node MISMATCH without counting a required tool missing" "$status"

# 12b. The control for the case above: a node on the floor is present, so the
#      MISMATCH cannot be reached by a report that only ever says MISMATCH.
floor_dir="${WORKDIR}/floor-node/bin"
mkdir -p "$floor_dir"
cat >"${floor_dir}/node" <<'FAKE'
#!/bin/sh
echo 'v22.0.0'
FAKE
chmod +x "${floor_dir}/node"
json="$(env -u BAZEL_META_OUTPUT_BASE PATH="${floor_dir}:${PATH}" \
    "$DOCTOR" --json 2>/dev/null)" || true
status=0
printf '%s\n' "$json" | python3 -c '
import json, sys
report = json.loads(sys.stdin.read())
rows = [row for row in report["tools"] if row["tool"] == "node"]
assert rows, "the census dropped node"
assert rows[0]["status"] == "present", rows[0]
' >/dev/null 2>&1 || status=$?
check "a node on the floor is reported present" "$status"

# 12c. npm is in the census too, so a host without it is told which lane wants
#      it. It is an optional row: the docs lanes are host lanes, and a runner
#      that never builds the site still gets a green doctor.
status=0
printf '%s\n' "$census_rows" | grep -qE '^\s+"npm:' || status=$?
check "the census lists npm with the lane that needs it" "$status"
status=0
json="$(env -u BAZEL_META_OUTPUT_BASE PATH="$old_dir" "$DOCTOR" --json 2>/dev/null)" || true
printf '%s\n' "$json" | python3 -c '
import json, sys
report = json.loads(sys.stdin.read())
rows = [row for row in report["tools"] if row["tool"] == "npm"]
assert rows, "the census dropped npm"
assert rows[0]["kind"] == "optional", rows[0]
assert "docs-site" in rows[0]["needed_by"], rows[0]
' >/dev/null 2>&1 || status=$?
check "--json carries npm as an optional tool and names its lane" "$status"

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} doctor assertion(s) failed" >&2
    exit 1
fi
echo "SUCCESS: //tools/bazel/sh:doctor reports the host honestly"
