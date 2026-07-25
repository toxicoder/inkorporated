#!/usr/bin/env bash
# ## Manage Inkorporated MkDocs site
# Local interface for serve, strict build, preview, and status.
#
# Usage:
#   ./docs/manage-docs.sh serve
#   ./docs/manage-docs.sh build
#   ./docs/manage-docs.sh build --strict
#   ./docs/manage-docs.sh preview
#   ./docs/manage-docs.sh status
#   ./docs/manage-docs.sh clean
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n ${BUILD_WORKSPACE_DIRECTORY:-} ]]; then
  REPO_ROOT="${BUILD_WORKSPACE_DIRECTORY}"
  SCRIPT_DIR="${REPO_ROOT}/docs"
else
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

VENV_DIR="${REPO_ROOT}/.venv-docs"
MKDOCS_YML="${REPO_ROOT}/mkdocs.yml"
DEFAULT_PORT=8000
PORT="${PORT:-$DEFAULT_PORT}"
: "${AUTO_SETUP_DOCS:=true}"

info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  serve [--port N] [--no-browser]   Live preview (default port ${DEFAULT_PORT})
  build [--strict]                  Production build into site/
  preview [--port N]                Strict build then serve site/
  status                            Show env and config status
  clean                             Remove site/ and optionally venv
  help                              Show this help

Environment:
  PORT                 Override serve port (default ${DEFAULT_PORT})
  AUTO_SETUP_DOCS      Create venv automatically (default true)
  INK_DOCS_VERSION     latest|development (stamps hooks / mike)
  MIKE_DOCS_VERSION    Prefer this over INK_DOCS_VERSION when set
EOF
}

ensure_env() {
  if [[ ! -f "$MKDOCS_YML" ]]; then
    error "Missing mkdocs.yml at repo root: $MKDOCS_YML"
    exit 1
  fi
  if [[ "$AUTO_SETUP_DOCS" == true ]]; then
    if [[ ! -x "${VENV_DIR}/bin/mkdocs" ]]; then
      info "Setting up docs virtualenv"
      bash "${SCRIPT_DIR}/setup-docs.sh" --quiet
    fi
  elif [[ ! -x "${VENV_DIR}/bin/mkdocs" ]]; then
    error "Docs venv missing. Run: ./docs/setup-docs.sh"
    exit 1
  fi
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
}

generate_cyborg_docs() {
  info "Generating cyborg roster docs"
  # Prefer active venv python (set by ensure_env); fall back to python3.
  if command -v python >/dev/null 2>&1; then
    python "${SCRIPT_DIR}/generate_cyborg_docs.py"
  else
    python3 "${SCRIPT_DIR}/generate_cyborg_docs.py"
  fi
}

validate_docs_links() {
  info "Validating docs link conventions (branch-aware / relative)"
  if command -v python >/dev/null 2>&1; then
    python "${SCRIPT_DIR}/validate_docs_links.py" --strict
  else
    python3 "${SCRIPT_DIR}/validate_docs_links.py" --strict
  fi
}

cmd_serve() {
  local no_browser=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port) PORT="$2"; shift 2 ;;
      --no-browser) no_browser=true; shift ;;
      *) shift ;;
    esac
  done
  ensure_env
  generate_cyborg_docs
  info "Serving docs on http://127.0.0.1:${PORT}"
  local args=(serve -f "$MKDOCS_YML" -a "127.0.0.1:${PORT}")
  if [[ "$no_browser" == true ]]; then
    args+=(--no-browser)
  fi
  mkdocs "${args[@]}"
}

cmd_build() {
  local strict=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict) strict=true; shift ;;
      *) shift ;;
    esac
  done
  ensure_env
  generate_cyborg_docs
  if [[ "$strict" == true ]]; then
    validate_docs_links
  fi
  cd "$REPO_ROOT"
  local args=(build -f "$MKDOCS_YML" -d "${REPO_ROOT}/site")
  if [[ "$strict" == true ]]; then
    args+=(--strict)
    info "Building documentation (strict)"
  else
    info "Building documentation"
  fi
  mkdocs "${args[@]}"
  success "Site written to ${REPO_ROOT}/site"
}

cmd_preview() {
  local port="$PORT"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port) port="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  cmd_build --strict
  ensure_env
  info "Serving built site on http://127.0.0.1:${port}"
  python -m http.server "$port" --directory "${REPO_ROOT}/site"
}

cmd_status() {
  echo "Repo root:     $REPO_ROOT"
  echo "mkdocs.yml:    $MKDOCS_YML ($([ -f "$MKDOCS_YML" ] && echo ok || echo MISSING))"
  echo "venv:          $VENV_DIR ($([ -x "${VENV_DIR}/bin/mkdocs" ] && echo ready || echo not installed))"
  echo "INK_DOCS_VERSION=${INK_DOCS_VERSION:-}"
  echo "MIKE_DOCS_VERSION=${MIKE_DOCS_VERSION:-}"
  if [[ -x "${VENV_DIR}/bin/mkdocs" ]]; then
    # shellcheck disable=SC1091
    source "${VENV_DIR}/bin/activate"
    mkdocs --version || true
  fi
}

cmd_clean() {
  rm -rf "${REPO_ROOT}/site"
  success "Removed site/"
  if [[ "${1:-}" == "--venv" ]]; then
    rm -rf "$VENV_DIR"
    success "Removed .venv-docs/"
  fi
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    serve) cmd_serve "$@" ;;
    build) cmd_build "$@" ;;
    preview) cmd_preview "$@" ;;
    status) cmd_status "$@" ;;
    clean) cmd_clean "$@" ;;
    help|-h|--help) usage ;;
    *) error "Unknown command: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
