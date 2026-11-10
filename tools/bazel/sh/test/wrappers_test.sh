#!/bin/bash
# Unit tests for the gate wrapper scripts: they must fail loudly when they are
# misconfigured, and each one must be shaped the way the gate expects.
#
# Run with: bazelisk test //tools/bazel/sh/test:wrappers_test

set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SH_DIR="${HERE}/.."
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

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# 1. Every wrapper is a real entry point: bash shebang, executable, and it
#    reaches the repository through gate_lib.sh rather than a guessed cwd.
wrappers=()
for script in "$SH_DIR"/run_*.sh "$SH_DIR"/doctor.sh "$SH_DIR"/run_suite.sh; do
    [ -f "$script" ] && wrappers+=("$script")
done
if [ "${#wrappers[@]}" -lt 6 ]; then
    echo "FAIL - expected at least 6 wrapper scripts, found ${#wrappers[@]}" >&2
    failures=$((failures + 1))
else
    check "the wrapper set is present (${#wrappers[@]} scripts)" 0
fi
missing=""
for script in "${wrappers[@]}"; do
    head -1 "$script" | grep -Eq '^#!(/bin/bash|/usr/bin/env bash|/bin/env bash)$' ||
        missing="${missing} $(basename "$script"):shebang"
    [ -x "$script" ] || missing="${missing} $(basename "$script"):not-executable"
done
if [ -z "$missing" ]; then
    check "every wrapper has a bash shebang and the executable bit" 0
else
    check "every wrapper has a bash shebang and the executable bit (${missing# })" 1
fi

# 2. run_suite.sh refuses to run a suite nobody named, instead of vacuously
#    passing on an empty target list.
status=0
out="$(env -u SUITE_TARGETS SUITE_TAG_FILTERS= bash "${SH_DIR}/run_suite.sh" 2>&1)" || status=$?
if [ "$status" -eq 2 ] && printf '%s' "$out" | grep -q 'SUITE_TARGETS'; then
    check "run_suite.sh exits 2 and names SUITE_TARGETS when it is empty" 0
else
    check "run_suite.sh exits 2 and names SUITE_TARGETS when it is empty (exit ${status})" 1
fi

# 3. run_suite.sh says so when its library is not shipped with it, which is the
#    failure a missing data dependency produces.
mkdir -p "${WORKDIR}/stripped"
cp "${SH_DIR}/run_suite.sh" "${WORKDIR}/stripped/run_suite.sh"
status=0
out="$(SUITE_TARGETS='//...' bash "${WORKDIR}/stripped/run_suite.sh" 2>&1)" || status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -q 'gate_lib.sh'; then
    check "run_suite.sh reports a missing gate_lib.sh instead of a bare 127" 0
else
    check "run_suite.sh reports a missing gate_lib.sh instead of a bare 127 (exit ${status})" 1
fi

# 4. The strict wrappers pass both halves of the nested-Bazel flags, so a
#    checker cannot end up putting a command option in startup position.
missing=""
for script in "${SH_DIR}/run_gate_policy.sh" "${SH_DIR}/run_owned_files_check.sh"; do
    # The value starts with --, so argparse only accepts it in the --flag=value
    # form; a space-separated form makes the checker report "expected one
    # argument" and the lane dies without checking anything.
    grep -q -- '--bazel-args="${BAZEL_META\[\*\]}"' "$script" ||
        missing="${missing} $(basename "$script"):startup"
    grep -q -- '--bazel-query-args="${BAZEL_META_OPTS\[\*\]}"' "$script" ||
        missing="${missing} $(basename "$script"):command"
done
if [ -z "$missing" ]; then
    check "the checker wrappers pass startup and command options separately" 0
else
    check "the checker wrappers pass startup and command options separately (${missing# })" 1
fi

# 5. run_coverage.sh must not print a floor it never measured. It re-executes
#    itself under xtrace before it does any work, so no other test ever runs
#    that bootstrap; and it asks python3 to answer, so a PATH without python3 is
#    the host condition in which the driver has nothing to report. The withheld
#    PATH is built from every directory the caller has, so the only thing the
#    driver can be missing is the interpreter.
no_python_dir="${WORKDIR}/no-python/bin"
mkdir -p "$no_python_dir"
IFS=: read -ra path_dirs <<< "$PATH"
for dir in "${path_dirs[@]}"; do
    [ -d "$dir" ] || continue
    for tool in "${dir}"/*; do
        [ -x "$tool" ] && [ ! -d "$tool" ] || continue
        name="$(basename "$tool")"
        case "$name" in
            python3 | python3.* | python) continue ;;
        esac
        [ -e "${no_python_dir}/${name}" ] || ln -s "$tool" "${no_python_dir}/${name}"
    done
done
if PATH="$no_python_dir" command -v python3 >/dev/null 2>&1; then
    # The driver would run the whole lane instead of failing, so stop here: this
    # is a broken fixture, not a passing test.
    check "the withheld PATH really withholds python3" 1
else
    check "the withheld PATH really withholds python3" 0
    status=0
    out="$(env -u COVERAGE_TRACED -u COVERAGE_TRACE_FILE -u COVERAGE_REPO_ROOT \
        -u COVERAGE_SH_DIR PATH="$no_python_dir" \
        bash -x "${SH_DIR}/run_coverage.sh" 2>&1)" || status=$?
    check "the coverage driver exits 127 when the checker cannot run" \
        "$([ "$status" -eq 127 ] && echo 0 || echo "1 (exit ${status})")"
    status=0
    printf '%s\n' "$out" | grep -q 'python3: command not found' || status=$?
    check "the driver says which binary it could not run" "$status"
    status=0
    printf '%s\n' "$out" | grep -q 'gate_lib\.sh.*python3: command not found' ||
        status=$?
    check "the failure comes from the library that runs the checker" "$status"
    status=0
    if printf '%s\n' "$out" | grep -q 'summary: .*floor'; then
        status=1
    fi
    check "the driver reports no coverage summary it did not measure" "$status"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} wrapper assertion(s) failed" >&2
    exit 1
fi
echo "SUCCESS: the gate wrappers fail loudly and are shaped as the gate expects"
