#!/usr/bin/env bash
#
# ## manage-docs
#
# Bazel / local interface for the Fumadocs (Next.js) documentation site.
#
# Usage:
#   bazelisk run //docs:serve      # live preview with hot reload
#   bazelisk run //docs:docs       # generate + static export into docs-site/out/
#   bazelisk run //docs:generate   # generators only, no npm and no export
#   bazelisk run //docs:preview    # strict build, then serve the export
#
# Safety: Writes generated markdown and docs-site/out/ only. No cluster, no cloud calls.

set -euo pipefail

SCRIPT_SRC="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SRC}")" && pwd)"
# A Bazel test is handed a runfiles copy, but the npm tree, the committed render under
# docs/cyborgs/generated, and docs-site/out/ all live in the real checkout. The runfiles
# directory is a tree of symlinks, so resolving the *directory* stays inside bazel-out;
# walk up from the script's own resolved path until the git directory appears -- the same
# route the gate checkers use.
resolve_repo_root() {
  local self dir
  self="$(readlink -f "${SCRIPT_SRC}" 2>/dev/null || printf '%s' "${SCRIPT_SRC}")"
  dir="$(dirname "${self}")"
  while [[ "${dir}" != "/" && ! -d "${dir}/.git" ]]; do
    dir="$(dirname "${dir}")"
  done
  if [[ -d "${dir}/.git" ]]; then
    printf '%s' "${dir}"
  fi
}

if [[ -n ${BUILD_WORKSPACE_DIRECTORY:-} && -d ${BUILD_WORKSPACE_DIRECTORY} ]]; then
  REPO_ROOT="${BUILD_WORKSPACE_DIRECTORY}"
else
  REPO_ROOT="$(resolve_repo_root)"
  if [[ -z "${REPO_ROOT}" ]]; then
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
  fi
fi
SCRIPT_DIR="${REPO_ROOT}/docs"
SITE_DIR="${REPO_ROOT}/docs-site"
DEFAULT_PORT=3005
PORT="${PORT:-${DEFAULT_PORT}}"
AUTO_OPEN_BROWSER=true
: "${AUTO_SETUP_DOCS:=true}"

info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

#######################################
# Pick the interpreter the generators run under.
#
# The generators read cyborgs/*.yaml, so they import PyYAML. docs/setup-docs.sh creates
# .venv-docs only when the host python3 cannot import it, so prefer that venv when it
# exists and fall back to the host interpreter otherwise.
# Globals:
#   REPO_ROOT
# Outputs:
#   The interpreter name or path, with no newline
# Returns:
#   0 always; a broken venv falls back rather than failing the caller
#######################################
resolve_docs_python() {
  local venv="${REPO_ROOT}/.venv-docs/bin/python"
  if [[ -x "${venv}" ]] && "${venv}" -c 'import yaml' >/dev/null 2>&1; then
    printf '%s' "${venv}"
  else
    printf 'python3'
  fi
}
DOCS_PYTHON="$(resolve_docs_python)"

usage() {
  cat <<EOF
Usage: bazelisk run //docs:manage-docs -- <command> [options]

Commands:
  serve [--port N] [--no-browser]   Live preview (default port ${DEFAULT_PORT})
  build [--strict]                  Generate + static export into docs-site/out/
  generate                          Run the page generators only
  generate-one <module>             Run one generator, e.g. generate_cyborg_docs
  validate-links                    Branch-aware / relative link check only
  preview [--port N]                Build then serve docs-site/out/
  status                            Show toolchain, nav and export status
  clean                             Remove local build artifacts
  help                              Show this help

Environment:
  PORT                 Override serve port (default ${DEFAULT_PORT})
  AUTO_SETUP_DOCS      Install the npm tree automatically (default true)
  INK_DOCS_VERSION     latest|development (stamps edit links and the dev banner)
  INK_DOCS_GIT_REF     Override the ref Edit-this-page links point at
EOF
}

#######################################
# Ensure Node 22+ and the docs-site dependencies.
# Globals:
#   SITE_DIR, AUTO_SETUP_DOCS, SCRIPT_DIR
# Outputs:
#   Error lines when the toolchain is missing
# Returns:
#   Exits 1 when Node/npm cannot satisfy the build
#######################################
docs_node_is_ready() {
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "docs: Node.js 22+ and npm are required for the documentation site." >&2
    echo "docs: Install them, then run: bazelisk run //docs-site:install" >&2
    exit 1
  fi
  local node_major
  node_major="$(node -p 'Number.parseInt(process.versions.node.split(".")[0], 10)' 2>/dev/null || echo 0)"
  if [[ ! ${node_major:-0} =~ ^[0-9]+$ ]] || [[ ${node_major:-0} -lt 22 ]]; then
    echo "docs: Node is too old for Next 16 (need 22+); found $(node --version)." >&2
    exit 1
  fi
  if [[ ! -x ${SITE_DIR}/node_modules/.bin/next ]]; then
    if [[ ${AUTO_SETUP_DOCS} == "true" ]]; then
      QUIET=true "${SCRIPT_DIR}/setup-docs.sh" || {
        echo "docs: failed to prepare the docs site via docs/setup-docs.sh" >&2
        exit 1
      }
    else
      echo "docs: docs-site/node_modules is missing. Run bazelisk run //docs-site:install first." >&2
      exit 1
    fi
  fi
}

#######################################
# Run the generator that fills docs/cyborgs/generated/.
# Globals:
#   REPO_ROOT
# Arguments:
#   None
# Outputs:
#   Generator log
# Returns:
#   0; a generator failure is fatal
#######################################
generate_code_docs() {
  "${DOCS_PYTHON}" "${REPO_ROOT}/docs/generate_cyborg_docs.py"
}

#######################################
# Regenerate the derived pages only, with no npm install and no export.
# Globals:
#   REPO_ROOT
# Arguments:
#   None
# Outputs:
#   Generator log, then the count of files under docs/cyborgs/generated/
# Returns:
#   0; generator failures are fatal
#######################################
docs_generate() {
  generate_code_docs
  echo "Regenerated docs/cyborgs/generated/ ($(find "${REPO_ROOT}/docs/cyborgs/generated" -type f | wc -l) files)."
  echo "Commit the diff; //docs:generated_render_current compares it against cyborgs/*.yaml."
}

#######################################
# Run exactly one generator, for a tight edit-run-print loop on that one file.
# Globals:
#   REPO_ROOT
# Arguments:
#   $1 - generator module name without .py, e.g. generate_cyborg_docs
# Outputs:
#   The generator's own log, then a reminder to commit the render
# Returns:
#   0; an unknown generator name exits 2 and a failing generator is fatal
#######################################
docs_generate_one() {
  local name="${1:-}"
  case "${name}" in
    generate_cyborg_docs) ;;
    *)
      echo "docs/manage-docs.sh: unknown generator: ${name} (try generate_cyborg_docs)" >&2
      exit 2
      ;;
  esac
  "${DOCS_PYTHON}" "${REPO_ROOT}/docs/${name}.py"
  echo "Regenerated one render through ${name}.py; commit the diff under docs/cyborgs/generated/."
}

#######################################
# Copy content assets into the Next public tree.
#
# The roster stylesheets are app-owned (docs-site/app/styles) so a page never has to
# reach into docs/ to look right; this covers images and other files a page links to.
# Globals:
#   REPO_ROOT, SITE_DIR
# Arguments:
#   None
# Returns:
#   0
#######################################
sync_public_assets() {
  mkdir -p "${SITE_DIR}/public"
  if [[ -d ${REPO_ROOT}/docs/assets ]]; then
    rm -rf "${SITE_DIR}/public/assets"
    cp -R "${REPO_ROOT}/docs/assets" "${SITE_DIR}/public/assets"
  fi
}

#######################################
# Regenerate the nav file so a page added since the last commit is in the menu.
# Globals:
#   REPO_ROOT
# Arguments:
#   None
# Outputs:
#   gen_nav's own line, or nothing when the committed tree is already current
# Returns:
#   0; a nav that contradicts the tree is fatal
#######################################
sync_nav() {
  python3 "${SITE_DIR}/scripts/gen_nav.py" || {
    echo "docs: docs-site/lib/nav.json does not match docs/ - fix the page or DIRECTORY_TABS" >&2
    exit 1
  }
}

#######################################
# Generate + static export.
# Globals:
#   REPO_ROOT, SITE_DIR, NODE_OPTIONS, NEXT_TELEMETRY_DISABLED
# Arguments:
#   Optional --strict (accepted and ignored: the export is always strict) --version X
# Outputs:
#   Build logs
# Returns:
#   next build status
#######################################
docs_build() {
  local version=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict | --no-strict) shift ;;
      --version)
        version="$2"
        shift 2
        ;;
      *)
        echo "docs/manage-docs.sh: unknown build option: $1" >&2
        exit 2
        ;;
    esac
  done
  docs_node_is_ready
  generate_code_docs
  validate_docs_links
  sync_nav
  sync_public_assets
  export NEXT_TELEMETRY_DISABLED="${NEXT_TELEMETRY_DISABLED:-1}"
  # ~870 MDX pages are compiled during static generation; give the heap room on a
  # 7 GB runner even before Bazel's JVM is considered.
  if [[ -z ${NODE_OPTIONS:-} ]]; then
    export NODE_OPTIONS="--max-old-space-size=5120"
  fi
  local build_script="build"
  case "${version}" in
    "") ;;
    latest) build_script="build:latest" ;;
    development) build_script="build:development" ;;
    *)
      echo "docs: --version must be latest or development, got ${version}" >&2
      exit 1
      ;;
  esac
  (cd "${SITE_DIR}" && npm run "${build_script}")
  success "Build complete. Output is in docs-site/out/"
}

#######################################
# Serve the Next dev server.
# Globals:
#   SITE_DIR, PORT, AUTO_OPEN_BROWSER
# Arguments:
#   --port N, --no-browser
# Outputs:
#   Dev server
# Returns:
#   next dev status
#######################################
docs_serve() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port)
        PORT="$2"
        shift 2
        ;;
      --no-browser)
        AUTO_OPEN_BROWSER=false
        shift
        ;;
      *)
        echo "docs/manage-docs.sh: unknown serve option: $1" >&2
        exit 2
        ;;
    esac
  done
  docs_node_is_ready
  generate_code_docs
  sync_nav
  sync_public_assets
  if [[ ${AUTO_OPEN_BROWSER} == "true" ]] && command -v python3 >/dev/null 2>&1; then
    python3 -m webbrowser "http://localhost:${PORT}" 2>/dev/null || true
  fi
  (cd "${SITE_DIR}" && exec npm run dev -- --port "${PORT}" --hostname localhost)
}

validate_docs_links() {
  info "Validating docs link conventions (branch-aware / relative)"
  python3 "${SCRIPT_DIR}/validate_docs_links.py" --strict
}

cmd_validate_links() {
  # The link checker is stdlib-only, so this lane needs no npm tree.
  validate_docs_links
  success "Docs link conventions validated"
}

#######################################
# Print docs tool status.
# Globals:
#   REPO_ROOT, SITE_DIR
# Arguments:
#   None
# Outputs:
#   Status lines
# Returns:
#   0
#######################################
docs_status() {
  echo "REPO_ROOT=${REPO_ROOT}"
  echo "Content root:          $([ -d "${REPO_ROOT}/docs" ] && echo 'docs/' || echo 'MISSING')"
  echo "Navigation tree:       $([ -f "${SITE_DIR}/lib/nav.json" ] && echo 'docs-site/lib/nav.json' || echo 'MISSING')"
  echo "source.config.ts:      $([ -f "${SITE_DIR}/source.config.ts" ] && echo 'present' || echo 'MISSING')"
  if command -v node >/dev/null 2>&1; then
    echo "Node:                  $(node --version)"
  else
    echo "Node:                  not in PATH"
  fi
  if [[ -x ${SITE_DIR}/node_modules/.bin/next ]]; then
    echo "Dependencies:          installed"
  else
    echo "Dependencies:          not installed (run bazelisk run //docs-site:install)"
  fi
  echo "Static export:         $([ -f "${SITE_DIR}/out/index.html" ] && echo 'docs-site/out/' || echo 'not built')"
  echo "INK_DOCS_VERSION=${INK_DOCS_VERSION:-}"
  echo "INK_DOCS_GIT_REF=${INK_DOCS_GIT_REF:-}"
}

#######################################
# Remove local Next build artifacts.
# Globals:
#   SITE_DIR
# Arguments:
#   None
# Returns:
#   0
#######################################
docs_clean() {
  rm -rf "${SITE_DIR}/out" "${SITE_DIR}/.next" "${SITE_DIR}/.source" "${SITE_DIR}/public/assets"
  success "Removed docs-site build artifacts"
}

#######################################
# Export then serve the static tree.
# Globals:
#   SITE_DIR, PORT
# Arguments:
#   --port N
# Outputs:
#   Build + serve logs
# Returns:
#   0 on success
#######################################
docs_preview() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port)
        PORT="$2"
        shift 2
        ;;
      *) shift ;;
    esac
  done
  docs_build
  echo "Serving the static export from docs-site/out/ on port ${PORT}..."
  (cd "${SITE_DIR}" && npm run serve -- "${PORT}" out)
}

main() {
  local cmd="${1:-build}"
  shift || true
  case "${cmd}" in
    build | docs) docs_build "$@" ;;
    generate) docs_generate ;;
    generate-one) docs_generate_one "$@" ;;
    serve) docs_serve "$@" ;;
    validate-links) cmd_validate_links "$@" ;;
    status) docs_status ;;
    clean) docs_clean ;;
    preview) docs_preview "$@" ;;
    typecheck)
      docs_node_is_ready
      (cd "${SITE_DIR}" && npm run typecheck)
      ;;
    test)
      docs_node_is_ready
      (cd "${SITE_DIR}" && npm run unit)
      ;;
    -h | --help | help) usage ;;
    *)
      error "Unknown command: ${cmd}"
      usage
      exit 1
      ;;
  esac
}

main "$@"
