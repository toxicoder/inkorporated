#!/usr/bin/env bash
# ## Setup MkDocs documentation environment
# Creates .venv-docs and installs docs/requirements.txt.
#
# Usage:
#   bazelisk run //docs:setup-docs
#   bazelisk run //docs:setup-docs -- --quiet
set -euo pipefail

SCRIPT_SRC="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SRC}")" && pwd)"
# `bazelisk run` puts the executable in bazel-bin and the declared data in the
# runfiles tree beside it, so the requirements file has to be looked for in both
# places. The real path of the script reaches the runfiles copy through the
# symlink; the unresolved directory covers an invocation of this file directly.
real_script_dir="$(readlink -f "${SCRIPT_SRC}" 2>/dev/null || printf '%s' "${SCRIPT_SRC}")"
real_script_dir="$(cd "$(dirname "${real_script_dir}")" && pwd)"
REQ_FILE=""
for candidate in "${real_script_dir}/requirements.txt" "${SCRIPT_DIR}/requirements.txt"; do
  if [[ -f "${candidate}" ]]; then
    REQ_FILE="${candidate}"
    break
  fi
done
# The virtualenv belongs to the checkout, not to the sandbox: `bazelisk run`
# exports BUILD_WORKSPACE_DIRECTORY precisely so a run target can find it.
REPO_ROOT="${BUILD_WORKSPACE_DIRECTORY:-}"
if [[ -z "${REPO_ROOT}" || ! -d "${REPO_ROOT}" ]]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
VENV_DIR="${REPO_ROOT}/.venv-docs"
QUIET=false

for arg in "$@"; do
  case "$arg" in
    --quiet|-q) QUIET=true ;;
    --help|-h)
      echo "Usage: bazelisk run //docs:setup-docs -- [--quiet]"
      exit 0
      ;;
  esac
done

info() { if [[ "$QUIET" != true ]]; then echo -e "\033[1;34m[INFO]\033[0m $*"; fi; }
success() { if [[ "$QUIET" != true ]]; then echo -e "\033[1;32m[SUCCESS]\033[0m $*"; fi; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

if [[ ! -f "$REQ_FILE" ]]; then
  error "Missing $REQ_FILE"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  error "python3 is required"
  exit 1
fi

if [[ ! -d "$VENV_DIR" ]]; then
  info "Creating venv at $VENV_DIR"
  python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"
info "Installing documentation dependencies"
python -m pip install --upgrade pip >/dev/null
pip install -r "$REQ_FILE"
success "Docs environment ready (${VENV_DIR})"
