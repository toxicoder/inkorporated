#!/usr/bin/env bash
# Run a named lane of the suite: the implementation behind //:gate and //:fast.
#
# Bazel 9 removed the native test_suite rule and left a stub that expands to
# nothing, and its successor module is not yet on the Bazel Central Registry,
# so an umbrella has to be a real test that runs the suite itself. The nested
# invocation uses its own output base and never re-enters an umbrella, so it
# cannot recurse and cannot contend with the invocation that started it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Bazel names the test executable after the target and drops it at the package
# root of runfiles, so gate_lib.sh is not always a sibling of $0. Resolve the
# symlink to find the directory the script really lives in, and fall back to the
# unresolved directory for the same-package case.
real_self="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
real_here="$(cd "$(dirname "$real_self")" && pwd)"
gate_lib=""
for candidate in "${real_here}/gate_lib.sh" "${here}/gate_lib.sh"; do
    if [[ -f "$candidate" ]]; then
        gate_lib="$candidate"
        break
    fi
done
if [[ -z "$gate_lib" ]]; then
    echo "error: gate_lib.sh is not in the runfiles of this target" >&2
    exit 2
fi
# shellcheck source=gate_lib.sh
source "$gate_lib"
resolve_repo_root
cd "${REPO_ROOT}"

if [[ -z "${SUITE_TARGETS:-}" ]]; then
  echo "error: SUITE_TARGETS must name the targets this umbrella runs" >&2
  exit 2
fi

# shellcheck disable=SC2206
targets=(${SUITE_TARGETS})
args=(test "${targets[@]}" --test_output=errors)

if [[ -n "${SUITE_TAG_FILTERS:-}" ]]; then
  args+=(--test_tag_filters="${SUITE_TAG_FILTERS}")
fi

if [[ -n "${SUITE_NOCACHE:-}" ]]; then
  args+=(--nocache_test_results)
fi

echo "lane: ${SUITE_LABEL:-suite}"
echo "command: bazelisk ${BAZEL_META[*]} ${args[*]} ${BAZEL_META_OPTS[*]}"
# TEST_TMPDIR and the TESTBRIDGE variables belong to this test, not to the
# nested invocation; leaving them set sends the nested server's output into a
# directory Bazel deletes as soon as this test finishes.
unset TEST_TMPDIR TESTBRIDGE_TEST_ONLY XML_OUTPUT_FILE
exec bazelisk "${BAZEL_META[@]}" "${args[@]}" "${BAZEL_META_OPTS[@]}"
