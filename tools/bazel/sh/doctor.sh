#!/usr/bin/env bash
# Report what the Bazel gates need from the host, without installing anything.
#
# Usage: bazelisk run //:doctor [-- --json]
#
# Every gate that depends on an optional host binary skips unless
# REQUIRE_LINT_TOOLS=1 or CI=1 is set. That skip is only honest while a person
# can ask, at any moment, which lanes really ran. This script answers that
# question and is the single source of truth for the required-tool list.
set -euo pipefail

if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  REPO_ROOT="${BUILD_WORKSPACE_DIRECTORY}"
else
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

# Tool -> the gate that needs it. Keep in sync with the strict = True targets
# in the BUILD files; //tools/bazel:gate_policy_check fails when a guard in a
# script names a tool that is missing from this list.
REQUIRED_TOOLS=(
  "git:every gate shells out to git ls-files"
  "python3://tools/bazel checkers and the docs generators"
  "shellcheck://lints:all shell style lane and //:verify_fix"
  "yamllint://lints:all YAML style lane"
  "ansible-lint://infrastructure/ansible:ansible_lint"
  "ansible://bootstrap/init_hybrid.sh (the hybrid bootstrap drives ansible directly)"
  "ansible-doc://infrastructure/ansible:ansible_lint (proves community.general is installed)"
  "terraform://infrastructure/terraform:terraform_fmt"
)

OPTIONAL_TOOLS=(
  "kubectl://tests/integration:test_authentik (live cluster branch only)"
  "helm://tests/deployment:test_helm (renders the charts under apps/)"
  "mkdocs://docs:build (lives in .venv-docs, created by //docs:setup-docs)"
  "python://the docs generators prefer the venv python over python3"
  "nvidia-smi://.devcontainer/scripts/tests:framework (gpu-detect.sh)"
  "aws://the cloud burst scripts under cloud/"
  "docker://a container build lane, if one is added"
)

MODE="text"
if [[ "${1:-}" == "--json" ]]; then
  MODE="json"
fi

present=0
missing=0
json_rows=""

report_tool() {
  local kind="$1" name="$2" why="$3" status
  if command -v "${name}" >/dev/null 2>&1; then
    status="present"
    if [[ "${kind}" == "required" ]]; then present=$((present + 1)); fi
  else
    status="MISSING"
    if [[ "${kind}" == "required" ]]; then missing=$((missing + 1)); fi
  fi
  if [[ "${MODE}" == "json" ]]; then
    if [[ -n "${json_rows}" ]]; then json_rows="${json_rows},"; fi
    json_rows="${json_rows}{\"tool\":\"${name}\",\"kind\":\"${kind}\",\"status\":\"${status}\",\"needed_by\":\"${why}\"}"
  else
    printf '  %-6s %-14s %-8s %s\n' "${kind}" "${name}" "${status}" "${why}"
  fi
}

if [[ "${MODE}" != "json" ]]; then
  echo "Inkorporated Bazel doctor  (repo root: ${REPO_ROOT})"
  echo "====================================================="
fi

if [[ -f "${REPO_ROOT}/.bazelversion" ]]; then
  pinned="$(tr -d '[:space:]' <"${REPO_ROOT}/.bazelversion")"
  # gate-policy: tool-guard exempt bazelisk is reported by this block itself
  if command -v bazelisk >/dev/null 2>&1; then
    actual="$(bazelisk --version 2>/dev/null | awk '{print $2}')"
  else
    actual="bazelisk MISSING"
  fi
  if [[ "${MODE}" == "json" ]]; then
    json_rows="{\"tool\":\"bazelisk\",\"kind\":\"required\",\"status\":\"$(
      [[ "${actual}" == "${pinned}" ]] && echo present || echo MISSING
    )\",\"needed_by\":\"every target; .bazelversion pins ${pinned}\"}"
  else
    if [[ "${actual}" == "${pinned}" ]]; then
      printf '  %-6s %-14s %-8s pinned by .bazelversion\n' "required" "bazelisk" "present"
    else
      printf '  %-6s %-14s %-8s .bazelversion pins %s\n' "required" "bazelisk" "MISMATCH" "${pinned}"
      missing=$((missing + 1))
    fi
  fi
fi

if [[ "${MODE}" != "json" ]]; then
  echo
  echo "Required by the strict lane:"
fi
for entry in "${REQUIRED_TOOLS[@]}"; do
  report_tool required "${entry%%:*}" "${entry#*:}"
done

if [[ "${MODE}" != "json" ]]; then
  echo
  echo "Optional; their gates skip when absent:"
fi
for entry in "${OPTIONAL_TOOLS[@]}"; do
  report_tool optional "${entry%%:*}" "${entry#*:}"
done

if [[ -d "${REPO_ROOT}/.venv-docs/bin" && -x "${REPO_ROOT}/.venv-docs/bin/mkdocs" ]]; then
  docs_env="ready"
else
  docs_env="not installed; run bazelisk run //docs:setup-docs"
fi

if [[ -e "${REPO_ROOT}/.devcontainer/.env" ]]; then
  env_mode="$(stat -c '%a' "${REPO_ROOT}/.devcontainer/.env" 2>/dev/null || echo unknown)"
else
  env_mode="absent (create from .devcontainer/.env.example)"
fi

if [[ "${MODE}" == "json" ]]; then
  echo "{\"bazel_version\":\"$( [[ -f "${REPO_ROOT}/.bazelversion" ]] && tr -d '[:space:]' <"${REPO_ROOT}/.bazelversion" )\",\"required_present\":${present},\"required_missing\":${missing},\"docs_venv\":\"${docs_env}\",\"devcontainer_env_mode\":\"${env_mode}\",\"tools\":[${json_rows}]}"
else
  echo
  echo "Host state:"
  printf '  %-24s %s\n' "docs virtualenv" "${docs_env}"
  printf '  %-24s %s\n' ".devcontainer/.env" "${env_mode}"
  echo
  if [[ "${missing}" -eq 0 ]]; then
    echo "All required tools present: the strict lane runs everything."
  else
    echo "${missing} required tool(s) missing."
    echo "Locally those lanes skip with a warning. Under REQUIRE_LINT_TOOLS=1"
    echo "or CI=1 they fail instead, so a green gate always means the tool ran."
  fi
fi

[[ "${missing}" -eq 0 ]] || exit 1
