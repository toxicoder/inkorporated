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

# node and npm sit here rather than above because the Fumadocs lanes are host
# lanes: //docs-site:* and //docs:build are tagged host/manual, named by CI, and
# the hermetic gate runs without them. node also lives outside the default PATH
# on images that install it under /opt, so a required row would redden the doctor
# for a lane the operator never runs. The version floor below still reports a
# stale node as MISMATCH.
OPTIONAL_TOOLS=(
  "kubectl://tests/integration:test_authentik (live cluster branch only)"
  "helm://tests/deployment:test_helm (renders the charts under apps/)"
  "python://the docs generators prefer the venv python over python3"
  "nvidia-smi://.devcontainer/scripts/tests:framework (gpu-detect.sh)"
  "aws://the cloud burst scripts under cloud/"
  "docker://a container build lane, if one is added"
  "node://docs-site:build (the Fumadocs site export; needs node 22 or newer)"
  "npm://docs-site:install (npm ci from the pinned docs-site/package-lock.json)"
)

MODE="text"
if [[ "${1:-}" == "--json" ]]; then
  MODE="json"
fi

present=0
missing=0
broken=0
json_rows=""

# tool_answers <name> is true when the binary runs far enough to print its
# version. Both spellings are tried because the CLIs disagree: --version for the
# python tools and terraform, a bare version subcommand for kubectl.
tool_answers() {
  local name="$1"
  "${name}" --version >/dev/null 2>&1 || "${name}" version >/dev/null 2>&1
}

# tool_min_major <name> prints the oldest major version a required tool may be
# on, and nothing when the lane only asks that the binary exist. The floor
# follows the toolchain the repository pins, not what happens to be installed.
tool_min_major() {
  case "$1" in
    node) printf '22' ;;
    *) printf '' ;;
  esac
}

# tool_major <name> prints the leading major version the tool reports about
# itself. node prefixes a v and npm appends a platform line, so everything from
# the first character a version cannot hold is dropped.
tool_major() {
  local raw
  raw="$("${1}" --version 2>/dev/null | head -n 1 || true)"
  raw="${raw#v}"
  raw="${raw%%[!0-9.]*}"
  printf '%s' "${raw%%.*}"
}

# version_at_least <name> <min-major> is true when the tool's own --version
# reports a major at or above the floor.
version_at_least() {
  local major min="$2"
  major="$(tool_major "$1")"
  [[ "${major}" =~ ^[0-9]+$ ]] && (( major >= min ))
}

report_tool() {
  local kind="$1" name="$2" why="$3" status major=""
  local min
  min="$(tool_min_major "${name}")"
  if ! command -v "${name}" >/dev/null 2>&1; then
    status="MISSING"
    if [[ "${kind}" == "required" ]]; then missing=$((missing + 1)); fi
  elif [[ "${kind}" == "required" ]] && ! tool_answers "${name}"; then
    # A required binary that cannot run is not installed as far as the gate is
    # concerned. command -v only asks whether the name resolves, so a symlink
    # into a python prefix whose modules resolve over a home directory reads as
    # present here and dies with ModuleNotFoundError inside a lane, where the
    # sandbox hands the action a home that is not the job's.
    status="BROKEN"
    missing=$((missing + 1))
    broken=$((broken + 1))
  elif [[ -n "${min}" ]] && tool_answers "${name}" &&
    ! version_at_least "${name}" "${min}"; then
    # On a runtime older than the lane pins, the name resolves and answers
    # --version, so the gate dies later on something that reads like a syntax
    # error. The Next export in docs-site/ needs node 22; say it here instead.
    # The floor is reported for an optional tool too, so a host that runs the
    # docs lane from CI sees why it failed, but only a required one reddens.
    major="$(tool_major "${name}")"
    status="MISMATCH"
    why="${why} (found ${major:-unknown}, needs ${min} or newer)"
    if [[ "${kind}" == "required" ]]; then missing=$((missing + 1)); fi
  else
    status="present"
    if [[ "${kind}" == "required" ]]; then present=$((present + 1)); fi
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

if [[ -x "${REPO_ROOT}/.venv-docs/bin/python" ]]; then
  docs_env="ready"
else
  docs_env="not installed; run bazelisk run //docs:setup-docs"
fi

# The site itself is the npm tree the Fumadocs build runs from; the same probe
# the docs-site npm runner uses to decide whether to run npm ci first.
if [[ -x "${REPO_ROOT}/docs-site/node_modules/.bin/next" ]]; then
  site_install="ready"
else
  site_install="not installed; run bazelisk run //docs:setup-docs"
fi

if [[ -e "${REPO_ROOT}/.devcontainer/.env" ]]; then
  env_mode="$(stat -c '%a' "${REPO_ROOT}/.devcontainer/.env" 2>/dev/null || echo unknown)"
else
  env_mode="absent (create from .devcontainer/.env.example)"
fi

if [[ "${MODE}" == "json" ]]; then
  echo "{\"bazel_version\":\"$( [[ -f "${REPO_ROOT}/.bazelversion" ]] && tr -d '[:space:]' <"${REPO_ROOT}/.bazelversion" )\",\"required_present\":${present},\"required_missing\":${missing},\"required_broken\":${broken},\"docs_venv\":\"${docs_env}\",\"docs_site_install\":\"${site_install}\",\"devcontainer_env_mode\":\"${env_mode}\",\"tools\":[${json_rows}]}"
else
  echo
  echo "Host state:"
  printf '  %-24s %s\n' "docs virtualenv" "${docs_env}"
  printf '  %-24s %s\n' "docs-site install" "${site_install}"
  printf '  %-24s %s\n' ".devcontainer/.env" "${env_mode}"
  echo
  if [[ "${missing}" -eq 0 ]]; then
    echo "All required tools present: the strict lane runs everything."
  else
    echo "${missing} required tool(s) missing."
    if [[ "${broken}" -gt 0 ]]; then
      echo "broken on PATH: ${broken} (the name resolves, --version does not run)."
      echo "A lane finds the name and then fails to run the tool."
      echo "Install the pinned set with the recipe in tools/bazel/lint-requirements.txt."
    fi
    echo "Locally those lanes skip with a warning. Under REQUIRE_LINT_TOOLS=1"
    echo "or CI=1 they fail instead, so a green gate always means the tool ran."
  fi
fi

[[ "${missing}" -eq 0 ]] || exit 1
