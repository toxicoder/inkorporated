#!/usr/bin/env bash
# Resolve the real checkout from the runfiles symlink a test was handed.
#
# The gate checkers ask questions about the repository -- which tracked files
# are unowned, which glob went unexplained, which doc still names a script
# path. A sandbox subset cannot answer those, so every wrapper locates the
# source tree this way and runs the checker against it.
#
# Usage: source this file, then use REPO_ROOT and gate_python.

# Bazel holds its workspace lock for the whole invocation, so a nested query
# must use its own output base or it waits forever. That is not only the outer
# invocation to avoid: an umbrella is itself a nested invocation, and the
# checkers it runs nest once more, so every action needs a base of its own.
# TEST_TMPDIR is the per-action scratch directory Bazel creates and deletes,
# which makes it unique by construction and writable inside the sandbox.
# Outside a test action nothing holds the lock, and a fixed per-user base keeps
# the analysis cache warm for a person running a wrapper by hand.
if [[ -n "${TEST_TMPDIR:-}" ]]; then
  _gate_meta_default="${TEST_TMPDIR}/bazel-meta"
else
  _gate_meta_default="/tmp/inkorporated-bazel-meta-$(id -u)"
fi
# Bazel names a startup option and has to lead the command line; --lockfile_mode
# is a command option and has to follow the verb, so the two live in separate
# arrays and Bazel never sees a startup option after the verb or a command
# option before it. The lockfile stays frozen so a nested server cannot race
# the outer one for MODULE.bazel.lock.
BAZEL_META_OUTPUT_BASE="${BAZEL_META_OUTPUT_BASE:-${_gate_meta_default}}"
BAZEL_META=(--output_base="${BAZEL_META_OUTPUT_BASE}")
BAZEL_META_OPTS=(--lockfile_mode=off)

resolve_repo_root() {
  local self
  self="$(readlink -f "${BASH_SOURCE[1]:-$0}" 2>/dev/null || echo "${BASH_SOURCE[1]:-$0}")"
  local dir
  dir="$(dirname "${self}")"
  while [[ ! -d "${dir}/.git" && "${dir}" != "/" ]]; do
    dir="$(dirname "${dir}")"
  done
  if [[ ! -d "${dir}/.git" ]]; then
    echo "error: could not locate the repository root from ${self}" >&2
    return 1
  fi
  REPO_ROOT="${dir}"
}

gate_python() {
  local checker="$1"
  shift
  python3 "${REPO_ROOT}/tools/bazel/${checker}" "$@"
}
