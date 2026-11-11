#!/usr/bin/env bash
# ## setup-docs
#
# Idempotent setup for the documentation site and its generators.
#
#   bazelisk run //docs:setup-docs
#   # gate-policy: allow-script-path documented direct fallback for //docs:serve, which
#   # sources this file and calls the functions before any target is involved.
#   QUIET=true ./docs/setup-docs.sh    # direct fallback; //docs:serve calls it
#
# Two toolchains, because the site and the generators are separate:
#   - docs-site/node_modules, installed from the pinned docs-site/package-lock.json
#   - .venv-docs, holding the Python packages the page generators import
#
# The MkDocs virtualenv is gone: nothing here installs mkdocs, mkdocs-material or mike.
# Safety: Installs into docs-site/node_modules and .venv-docs. Never publishes.

set -euo pipefail

QUIET=${QUIET:-false}

SCRIPT_SRC="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SRC}")" && pwd)"
# `bazelisk run` puts the executable in bazel-bin and the declared data in the runfiles
# tree beside it, so the requirements file has to be looked for in both places.
real_script_dir="$(readlink -f "${SCRIPT_SRC}" 2>/dev/null || printf '%s' "${SCRIPT_SRC}")"
real_script_dir="$(cd "$(dirname "${real_script_dir}")" && pwd)"

REPO_ROOT="${BUILD_WORKSPACE_DIRECTORY:-}"
if [[ -z "${REPO_ROOT}" || ! -d "${REPO_ROOT}" ]]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
SITE_DIR="${REPO_ROOT}/docs-site"
VENV_DIR="${REPO_ROOT}/.venv-docs"

REQ_FILE=""
for candidate in "${real_script_dir}/requirements.txt" "${SCRIPT_DIR}/requirements.txt"; do
  if [[ -f "${candidate}" ]]; then
    REQ_FILE="${candidate}"
    break
  fi
done

info() { if [[ "${QUIET}" != true ]]; then echo -e "\033[1;34m[INFO]\033[0m $*"; fi; }
success() { if [[ "${QUIET}" != true ]]; then echo -e "\033[1;32m[SUCCESS]\033[0m $*"; fi; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

for arg in "$@"; do
  case "${arg}" in
    --quiet | -q) QUIET=true ;;
    --help | -h)
      echo "Usage: bazelisk run //docs:setup-docs -- [--quiet]"
      exit 0
      ;;
  esac
done

#######################################
# Install the Next.js app dependencies from the pinned lockfile.
# Globals:
#   SITE_DIR, QUIET
# Returns:
#   0 when present or installed; 1 when npm cannot do it
#######################################
docs_install_site_deps() {
  if [[ ! -f ${SITE_DIR}/package.json ]]; then
    error "setup-docs: docs-site/package.json not found"
    return 1
  fi
  # gate-policy: tool-guard exempt this is the installer, not a gate: a missing npm returns 1
  # and the caller exits 1, so there is no silent-skip path for REQUIRE_LINT_TOOLS to harden.
  if ! command -v npm >/dev/null 2>&1; then
    error "setup-docs: npm is required (Node.js 22+)"
    return 1
  fi
  if [[ -x ${SITE_DIR}/node_modules/.bin/next && -x ${SITE_DIR}/node_modules/.bin/vitest ]]; then
    info "docs-site dependencies already installed"
    return 0
  fi
  info "Installing docs-site dependencies from docs-site/package-lock.json"
  (cd "${SITE_DIR}" && npm ci --legacy-peer-deps) || {
    error "setup-docs: npm ci failed in docs-site/"
    return 1
  }
}

#######################################
# Create .venv-docs for the generators' Python imports.
#
# The generators under docs/ read cyborgs/*.yaml, so they need PyYAML. When the host
# python3 already imports it, no venv is created and no download happens.
# Globals:
#   VENV_DIR, REQ_FILE, QUIET
# Returns:
#   0 when the imports resolve; 1 otherwise
#######################################
docs_install_python_deps() {
  # gate-policy: tool-guard exempt same reason as the npm probe above: the installer fails
  # loudly when python3 is absent, and python3 is a required row in the doctor census.
  if ! command -v python3 >/dev/null 2>&1; then
    error "setup-docs: python3 is required"
    return 1
  fi
  if [[ -x "${VENV_DIR}/bin/python" ]] && "${VENV_DIR}/bin/python" -c 'import yaml' >/dev/null 2>&1; then
    info "generator virtualenv already ready"
    return 0
  fi
  if python3 -c 'import yaml' >/dev/null 2>&1; then
    info "python3 already provides the generator imports; no venv needed"
    return 0
  fi
  if [[ -z "${REQ_FILE}" ]]; then
    error "setup-docs: docs/requirements.txt not found and python3 lacks its packages"
    return 1
  fi
  if [[ ! -d "${VENV_DIR}" ]]; then
    info "Creating venv at ${VENV_DIR}"
    python3 -m venv "${VENV_DIR}" || {
      error "setup-docs: could not create ${VENV_DIR}"
      return 1
    }
  fi
  info "Installing generator dependencies from ${REQ_FILE}"
  "${VENV_DIR}/bin/python" -m pip install --upgrade pip >/dev/null || {
    error "setup-docs: pip is unavailable in ${VENV_DIR}"
    return 1
  }
  "${VENV_DIR}/bin/python" -m pip install -r "${REQ_FILE}" || {
    error "setup-docs: could not install ${REQ_FILE}"
    return 1
  }
}

docs_install_site_deps || exit 1
docs_install_python_deps || exit 1
success "Documentation toolchain ready (docs-site/node_modules${VENV_DIR:+, ${VENV_DIR}})"
