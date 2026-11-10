#!/usr/bin/env bash
# Condition 2: every glob() carries a policy and the total stays inside budget.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gate_lib.sh
source "${here}/gate_lib.sh"
resolve_repo_root

gate_python glob_budget.py --root "${REPO_ROOT}" --max "${GLOB_BUDGET:-14}" "$@"
