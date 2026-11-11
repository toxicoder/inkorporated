#!/usr/bin/env bash
# Wrapper for docs/test_docs_site_render.py (source contract + optional export checks).
#
# Bazel runs this from a runfiles tree, so BUILD_WORKSPACE_DIRECTORY is the checkout the
# checks must read; outside Bazel the script's own directory names the repository.
set -euo pipefail

if [[ -n ${BUILD_WORKSPACE_DIRECTORY:-} ]]; then
  cd "${BUILD_WORKSPACE_DIRECTORY}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${SCRIPT_DIR}/.."
fi

exec python3 docs/test_docs_site_render.py "$@"
