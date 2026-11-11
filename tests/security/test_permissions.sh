#!/bin/bash
# Test file permissions for security.
#
# Three things are asserted, all of them about the checkout this test runs in:
#
#   1. .devcontainer/.env, the local secrets file, is 600 when it exists. Only
#      its mode is read; the file itself is never opened, printed, or handed to
#      Bazel as a data dependency, so no secret can leak through a build action.
#   2. .devcontainer/.env.example, the template every operator copies, is a
#      regular readable file that nobody but the owner can write and that no
#      shell can execute.
#   3. The tracked tree carries no key material, no dotenv file, no terraform
#      state, no world-writable file, and no executable that is not a shell
#      script with a shebang.
#
# The original script checked two files and printed a pass when neither check
# could run. There is no skip path here: each assertion either holds or the
# test exits 1.
set -euo pipefail

TARGET="//tests/security:test_permissions"
RERUN="Re-run with: bazelisk test ${TARGET} --test_output=errors --nocache_test_results"

# This lane asks about the checkout (tracked files, the local .env), so it
# resolves the real repository root from the runfiles symlink it was handed.
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
dir="${SCRIPT_DIR}"
while [[ "${dir}" != "/" && ! -d "${dir}/.git" ]]; do
  dir="$(dirname "${dir}")"
done
if [[ ! -d "${dir}/.git" ]]; then
  echo "FAIL: ${TARGET} needs a git checkout to list tracked files; none found above ${SCRIPT_DIR}" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi
REPO_ROOT="${dir}"
cd "${REPO_ROOT}"

if ! command -v git >/dev/null 2>&1; then
  echo "FAIL: git is a required //:doctor tool and is missing; it lists the tracked files of ${REPO_ROOT}" >&2
  echo "      (CI=${CI:-unset} REQUIRE_LINT_TOOLS=${REQUIRE_LINT_TOOLS:-unset})" >&2
  echo "      install it with: apt-get install -y git" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

# stat is probed by using it (GNU -c, then the BSD form) rather than by asking
# whether it exists: a coreutils install is not a gate tool //:doctor tracks,
# and this fails the lane either way.
if ! stat -c '%a' "${SCRIPT_PATH}" >/dev/null 2>&1 && ! stat -f '%Lp' "${SCRIPT_PATH}" >/dev/null 2>&1; then
  echo "FAIL: stat is required to read the mode of .devcontainer/.env and of every tracked file" >&2
  echo "      install it with: apt-get install -y coreutils" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

# The secret-path pattern needs look-ahead, so it is a PCRE. Without it the
# scan below would find nothing and report a clean tree, which is the failure
# mode this whole package exists to remove.
if ! printf 'probe\n' | grep -qP 'probe' 2>/dev/null; then
  echo "FAIL: grep with -P (PCRE) is required to scan the tracked file list" >&2
  echo "      install it with: apt-get install -y grep" >&2
  echo "      ${RERUN}" >&2
  exit 1
fi

failures=0
checked=()

note() {
  checked+=("$1")
}

record_failure() {
  echo "FAIL $1" >&2
  failures=$((failures + 1))
}

# mode_of prints the octal mode, or nothing when the file is unreadable by stat.
mode_of() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null || true
}

# --------------------------------------------------------------------------
# 1. The local secrets file: mode only, never contents.
# --------------------------------------------------------------------------
ENV_FILE="${REPO_ROOT}/.devcontainer/.env"
if [[ -e "${ENV_FILE}" ]]; then
  if [[ ! -f "${ENV_FILE}" ]]; then
    record_failure ".devcontainer/.env is not a regular file"
  else
    env_mode="$(mode_of "${ENV_FILE}")"
    if [[ -z "${env_mode}" ]]; then
      record_failure "could not read the mode of .devcontainer/.env"
    elif (( 8#${env_mode} & 8#0077 )); then
      record_failure ".devcontainer/.env is mode ${env_mode}; group or other can read it."
      echo "     fix: chmod 600 ${ENV_FILE}" >&2
    else
      note ".devcontainer/.env is mode ${env_mode}: owner read and write only"
    fi
  fi
else
  note ".devcontainer/.env is absent, so there is no local secret file to protect"
fi

# --------------------------------------------------------------------------
# 2. The template that seeds it.
# --------------------------------------------------------------------------
EXAMPLE_FILE="${REPO_ROOT}/.devcontainer/.env.example"
if [[ ! -f "${EXAMPLE_FILE}" ]]; then
  record_failure ".devcontainer/.env.example is missing; every operator needs the template"
else
  example_mode="$(mode_of "${EXAMPLE_FILE}")"
  if [[ -z "${example_mode}" ]]; then
    record_failure "could not read the mode of .devcontainer/.env.example"
  else
    if ! (( 8#${example_mode} & 8#0400 )); then
      record_failure ".devcontainer/.env.example is mode ${example_mode}: the owner cannot read it"
    fi
    if (( 8#${example_mode} & 8#0022 )); then
      record_failure ".devcontainer/.env.example is mode ${example_mode}: group or other can write it."
      echo "     fix: chmod 644 ${EXAMPLE_FILE}" >&2
    fi
    if (( 8#${example_mode} & 8#0111 )); then
      record_failure ".devcontainer/.env.example is mode ${example_mode}: it carries an exec bit"
    fi
    if ! (( 8#${example_mode} & 8#0004 )); then
      record_failure ".devcontainer/.env.example is mode ${example_mode}: it must stay world" \
        "readable so the dev container can copy it"
    fi
    if [[ ! -s "${EXAMPLE_FILE}" ]]; then
      record_failure ".devcontainer/.env.example is empty; it is the template every" \
        " operator copies, and its keys are what validate_config.sh demands"
    fi
    note ".devcontainer/.env.example is mode ${example_mode}: regular, world readable, owner-write only"
  fi
fi

# --------------------------------------------------------------------------
# 3. The tracked tree: no key material, no world-writable file, no odd exec.
# --------------------------------------------------------------------------
SECRET_PATTERN='(^|/)\.env$|(^|/)\.env\.(?!example)[A-Za-z]|\.pem$|\.key$|\.p12$|\.pfx$|(^|/)id_rsa|\.gpg$|credentials\.json$|(^|/)kubeconfig$|\.tfstate|\.tfvars$|\.tab$|\.p8$|\.keystore$|\.jks$'

tracked_count=0
secret_files=""
writable_files=""
exec_files=""

while IFS= read -r -d '' tracked; do
  tracked_count=$((tracked_count + 1))
  if printf '%s\n' "${tracked}" | grep -qP "${SECRET_PATTERN}"; then
    secret_files+="  ${tracked}"$'\n'
  fi
  [[ -f "${tracked}" && ! -L "${tracked}" ]] || continue
  mode="$(mode_of "${tracked}")"
  [[ -n "${mode}" ]] || continue
  if (( 8#${mode} & 8#0022 )); then
    writable_files+="  ${tracked} (mode ${mode})"$'\n'
  fi
  if (( 8#${mode} & 8#0111 )); then
    if [[ "${tracked}" != *.sh ]]; then
      exec_files+="  ${tracked} (mode ${mode}, not a shell script)"$'\n'
    elif ! head -c 2 "${tracked}" | grep -q '#!'; then
      exec_files+="  ${tracked} (mode ${mode}, no shebang)"$'\n'
    fi
  fi
done < <(git -C "${REPO_ROOT}" ls-files -z)

if [[ ${tracked_count} -eq 0 ]]; then
  record_failure "git ls-files returned nothing for ${REPO_ROOT}; nothing was checked"
fi
[[ -z "${secret_files}" ]] || record_failure "tracked files carry key material or local secrets:"$'\n'"${secret_files}"
[[ -z "${writable_files}" ]] || record_failure "tracked files are group or other writable:"$'\n'"${writable_files}"
[[ -z "${exec_files}" ]] || record_failure "tracked executables are not shebang shell scripts:"$'\n'"${exec_files}"

note "${tracked_count} tracked file(s): no dotenv, key, certificate, terraform state, or"
note "  credential file is committed; none is group or other writable; every exec bit is"
note "  on a shebang'd .sh"

# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
if (( failures > 0 )); then
  echo "" >&2
  echo "${failures} failure(s) in ${TARGET}" >&2
  echo "     ${RERUN}" >&2
  exit 1
fi

echo "PASS file permissions in ${REPO_ROOT}"
for line in "${checked[@]}"; do
  echo "     ${line}"
done
