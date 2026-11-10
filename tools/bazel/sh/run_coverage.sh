#!/usr/bin/env bash
# Condition 5: the gate's own tooling is covered, and the floor is 100%.
#
# Three things have to run under a tracer before a 100% line is worth
# printing, and this script is one of them: a coverage lane that never
# executes its own entry point is the likeliest thing in the repository to
# report a green floor it never measured. So it instruments itself. The first
# pass re-executes this same file under `bash -x` with the trace pointed at a
# file of its own; the second pass, marked by COVERAGE_TRACED and therefore
# being traced, does the real work and hands that file to the runner.
#
# The other two are the checker unit tests, which the runner traces in-process
# with sys.settrace, and the shell unit tests, which run under the same
# xtrace: bash inherits SHELLOPTS, so every script a test launches by absolute
# path is measured too, and that is what reaches gate_lib.sh and doctor.sh.
#
# Two entry points are executed by no unit test at all. The run_*.sh wrappers
# are only grepped by wrappers_test.sh, and doctor.sh is never run as
# //:doctor runs it, with BUILD_WORKSPACE_DIRECTORY pointing at the checkout.
# Both are executed here, under the tracer, and asserted on rather than just
# started: a lane that runs a script and ignores its exit code measures
# nothing.
#
# The tests run from the runfiles copy while the measurement follows the
# runfiles symlinks back to the source files, so the denominator is the code
# that ships, not a copy of it.
set -euo pipefail

# The four checker unit tests, as the runner sees them: repo-relative, because
# it loads them with unittest from the checkout it was pointed at.
PY_TESTS=(
  "tools/bazel/test/test_coverage_report.py"
  "tools/bazel/test/test_gate_policy.py"
  "tools/bazel/test/test_glob_budget.py"
  "tools/bazel/test/test_owned_files_check.py"
)

# The three shell unit tests. Each launches the scripts under measurement by
# absolute path, so their trace covers those scripts.
SH_TESTS=(
  "tools/bazel/sh/test/doctor_test.sh"
  "tools/bazel/sh/test/gate_lib_test.sh"
  "tools/bazel/sh/test/wrappers_test.sh"
)

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gate_lib.sh
source "${here}/gate_lib.sh"

if [[ "${COVERAGE_TRACED:-0}" != "1" ]]; then
  WORKDIR="$(mktemp -d)"
  export WORKDIR
  COVERAGE_TRACE_FILE="${WORKDIR}/driver.trace"
  export COVERAGE_TRACE_FILE
  : >"${COVERAGE_TRACE_FILE}"
  exec 9>"${COVERAGE_TRACE_FILE}"
  # PS4 carries the file and the line so the runner can attribute every trace
  # line. SHELLOPTS is what pulls the child shells into the measurement, but it
  # is a bash-internal readonly variable: assigning to it fails as soon as it
  # arrives from the inherited environment, which a Bazel test action does.
  # Enable the option first, then export the variable bash already maintains.
  # BASH_XTRACEFD keeps the trace off stderr and inside the file the runner
  # reads, so a failing lane reports findings rather than a trace dump.
  export PS4='+|${BASH_SOURCE}|${LINENO}|' COVERAGE_TRACED=1 BASH_XTRACEFD=9
  set -o xtrace
  export SHELLOPTS
  exec bash -x "${BASH_SOURCE[0]}" "$@"
fi

trap 'rm -rf "${WORKDIR:?}"' EXIT
resolve_repo_root
export COVERAGE_REPO_ROOT="${REPO_ROOT}"
export COVERAGE_SH_DIR="${here}"

# Scratch drivers, written under the temporary directory only. They are real
# invocations with real assertions, and they are passed to the runner as
# further shell tests, so a missing one is an error that names the file.
mkdir -p "${WORKDIR}/sh"

cat >"${WORKDIR}/sh/wrappers_executed.sh" <<'RUNNERS'
#!/usr/bin/env bash
# The wrappers as their Bazel targets run them. Each checker has to answer on
# its own, so a wrapper that lost a flag or its library fails here.
set -euo pipefail
for wrapper in run_glob_budget.sh run_gate_policy.sh run_owned_files_check.sh; do
  log="${WORKDIR}/${wrapper%.sh}.log"
  if ! bash "${COVERAGE_SH_DIR}/${wrapper}" >"${log}" 2>&1; then
    printf 'coverage: %s exited non-zero; its output follows\n' "${wrapper}" >&2
    cat "${log}" >&2
    exit 1
  fi
done
RUNNERS

cat >"${WORKDIR}/sh/doctor_as_bazel_run.sh" <<'DOCTOR'
#!/usr/bin/env bash
# doctor.sh the way `bazelisk run //:doctor` runs it: BUILD_WORKSPACE_DIRECTORY
# is what Bazel exports to a run target, and it is the only route by which the
# doctor finds the checkout it is reporting on and reads .bazelversion.
set -euo pipefail
export BUILD_WORKSPACE_DIRECTORY="${COVERAGE_REPO_ROOT}"
out="$(bash "${COVERAGE_SH_DIR}/doctor.sh" --json)"
printf '%s\n' "${out}" | python3 -c '
import json, sys
report = json.load(sys.stdin)
assert report["tools"], "the census came back empty"
assert report["bazel_version"], ".bazelversion was not read"
'
bash "${COVERAGE_SH_DIR}/doctor.sh" >/dev/null
DOCTOR

SH_TESTS+=("${WORKDIR}/sh/wrappers_executed.sh"
           "${WORKDIR}/sh/doctor_as_bazel_run.sh")

argv=(--root "${REPO_ROOT}" --min "${COVERAGE_FLOOR:-100}" --strict-ledger
      --sh-trace "${COVERAGE_TRACE_FILE}")
for test in "${PY_TESTS[@]}"; do
  argv+=(--test "${test}")
done
for test in "${SH_TESTS[@]}"; do
  argv+=(--sh-test "${test}")
done

gate_python coverage_report.py "${argv[@]}" "$@"
