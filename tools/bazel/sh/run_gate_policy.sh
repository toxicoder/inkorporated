#!/usr/bin/env bash
# Condition 4: prose, comments and printed help name targets, never script paths.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gate_lib.sh
source "${here}/gate_lib.sh"
resolve_repo_root

gate_python gate_policy.py --root "${REPO_ROOT}" \
  --bazel-args="${BAZEL_META[*]}" \
  --bazel-query-args="${BAZEL_META_OPTS[*]}" "$@"
