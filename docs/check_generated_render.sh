#!/usr/bin/env bash
# Fail when the committed cyborg roster no longer matches cyborgs/*.yaml.
#
# docs/cyborgs/generated/ is a render, not a source. Someone editing it by hand
# loses the change the next time anyone regenerates it, so this lane regenerates
# into a scratch tree and compares, without touching the checkout.
#
# Usage: bazelisk test //docs:generated_render_current
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [[ ! -x "${REPO_ROOT}/.venv-docs/bin/python" ]]; then
  real_script_dir="$(readlink -f "${SCRIPT_DIR}" 2>/dev/null || true)"
  if [[ -n "${real_script_dir}" && -x "${real_script_dir}/../.venv-docs/bin/python" ]]; then
    REPO_ROOT="$(cd "${real_script_dir}/.." && pwd)"
  fi
fi

PYTHON="${REPO_ROOT}/.venv-docs/bin/python"
if [[ ! -x "${PYTHON}" ]]; then
  echo "error: the docs virtualenv is missing; run bazelisk run //docs:setup-docs" >&2
  exit 1
fi

WORK="${TEST_TMPDIR:-$(mktemp -d)}/render"
mkdir -p "${WORK}/docs"
cp -r "${REPO_ROOT}/cyborgs" "${WORK}/cyborgs"
cp -r "${REPO_ROOT}/docs/job_roles" "${WORK}/docs/job_roles"
cp -r "${REPO_ROOT}/docs/cyborgs" "${WORK}/docs/cyborgs"
cp "${REPO_ROOT}/docs/generate_cyborg_docs.py" "${WORK}/docs/generate_cyborg_docs.py"

"${PYTHON}" "${WORK}/docs/generate_cyborg_docs.py" >/dev/null

status=0
# -r follows symlinks; the runfiles copy is a symlink farm into the checkout.
while IFS= read -r committed; do
  rel="${committed#"${REPO_ROOT}/"}"
  fresh="${WORK}/${rel}"
  if [[ ! -f "${fresh}" ]]; then
    echo "STALE   ${rel} is committed but the generator no longer writes it"
    status=1
    continue
  fi
  if ! cmp -s "${REPO_ROOT}/${rel}" "${fresh}"; then
    echo "STALE   ${rel} differs from a fresh render of cyborgs/*.yaml"
    echo "        regenerate with: bazelisk test //docs:build"
    status=1
  fi
done < <(find "${REPO_ROOT}/docs/cyborgs/generated" -type f -name '*.md' -o -type f -name '*.json' | sort)

if [[ "${status}" -eq 0 ]]; then
  echo "docs/cyborgs/generated matches cyborgs/*.yaml"
else
  echo "error: the committed render is stale; edit cyborgs/, never docs/cyborgs/generated/" >&2
fi
exit "${status}"
