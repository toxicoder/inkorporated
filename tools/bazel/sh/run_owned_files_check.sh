#!/usr/bin/env bash
# Condition 1: every tracked file is owned by a target or ledgered with a reason.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gate_lib.sh
source "${here}/gate_lib.sh"
resolve_repo_root

gate_python owned_files_check.py \
  --root "${REPO_ROOT}" \
  --strict-ledger \
  --bazel-args="${BAZEL_META[*]}" \
  --bazel-query-args="${BAZEL_META_OPTS[*]}" \
  "$@"
