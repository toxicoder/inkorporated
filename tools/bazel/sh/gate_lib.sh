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
# must use its own output base or it waits forever. --output_base is a startup
# option and has to lead the command line; --lockfile_mode is a command option
# and has to follow the verb, so the two live in separate arrays and Bazel
# never sees a startup option after the verb or a command option before it.
# The lockfile stays frozen so the nested server cannot race the outer one for
# MODULE.bazel.lock.
BAZEL_META_OUTPUT_BASE="${BAZEL_META_OUTPUT_BASE:-/tmp/inkorporated-bazel-meta}"
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
