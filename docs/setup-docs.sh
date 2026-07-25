#!/usr/bin/env bash
# ## Setup MkDocs documentation environment
# Creates .venv-docs and installs docs/requirements.txt.
#
# Usage:
#   ./docs/setup-docs.sh
#   ./docs/setup-docs.sh --quiet
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENV_DIR="${REPO_ROOT}/.venv-docs"
REQ_FILE="${SCRIPT_DIR}/requirements.txt"
QUIET=false

for arg in "$@"; do
  case "$arg" in
    --quiet|-q) QUIET=true ;;
    --help|-h)
      echo "Usage: $0 [--quiet]"
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
