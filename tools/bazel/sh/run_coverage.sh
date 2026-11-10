#!/usr/bin/env bash
# Condition 5: the gate's own tooling is covered, and the floor is 100%.
#
# The tests run from the runfiles copy while the measurement follows the
# runfiles symlinks back to the source files, so the denominator is the code
# that ships, not a copy of it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gate_lib.sh
source "${here}/gate_lib.sh"
resolve_repo_root

cd "${REPO_ROOT}"
gate_python coverage_report.py \
  --root "${REPO_ROOT}" \
  --min "${COVERAGE_FLOOR:-100}" \
  --test tools/bazel/test/test_coverage_report.py \
  --test tools/bazel/test/test_gate_policy.py \
  --test tools/bazel/test/test_glob_budget.py \
  --test tools/bazel/test/test_owned_files_check.py \
  --sh-test tools/bazel/sh/test/doctor_test.sh \
  --sh-test tools/bazel/sh/test/gate_lib_test.sh \
  --sh-test tools/bazel/sh/test/wrappers_test.sh \
  "$@"
