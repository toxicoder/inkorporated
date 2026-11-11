#!/bin/bash

# Wrapper script to run ansible-lint on the playbooks and roles of this package.
# This script is the action of //infrastructure/ansible:ansible_lint.

# Set exit on error
set -e

# The test stub lives in this package's runfiles directory, so the real path of
# this script names the package directory. Running from inside it is what makes
# ansible.cfg, .ansible-lint, and a bare role name in a playbook resolve.
here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# gate-policy: tool-guard exempt ansible-lint is reported by //:doctor
if ! command -v ansible-lint >/dev/null 2>&1; then
    if [ "${REQUIRE_LINT_TOOLS:-0}" = "1" ] || [ "${CI:-}" = "true" ] || [ "${CI:-}" = "1" ]; then
        echo "error: ansible-lint not found but REQUIRE_LINT_TOOLS/CI is set; install it or run //:doctor" >&2
        exit 1
    fi
    echo "WARN: ansible-lint not found, skipping (set REQUIRE_LINT_TOOLS=1 to make this fatal)"
    exit 0
fi

# A Bazel test action gets a throwaway HOME, so the ~/.ansible/collections
# directory that ansible-galaxy installs into is invisible to the lane unless it
# is named. Ask the passwd database for the real home of the uid running the
# test; this lane reads host tooling by design and //:doctor censuses it.
real_home="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)"
repo_root="$(cd "$here" && git rev-parse --show-toplevel 2>/dev/null || echo "$here")"

# The playbooks use modules from community.general, and ansible-lint reports an
# unresolvable module as a fatal syntax error, so the collection is part of what
# this lane needs. ansible-galaxy exits 0 on an unusable path and ansible-doc
# exits 0 on a module it never found, so the check is the directory itself.
collection_probe() {
    local base
    for base in ${ANSIBLE_COLLECTIONS_PATH//:/ }; do
        if [ -d "$base/ansible_collections/community/general" ]; then
            return 0
        fi
    done
    return 1
}

search_paths=()
[ -n "${ANSIBLE_COLLECTIONS_PATH:-}" ] && search_paths+=("$ANSIBLE_COLLECTIONS_PATH")
[ -n "$real_home" ] && search_paths+=("$real_home/.ansible/collections")
search_paths+=("$repo_root/.ansible-collections")
search_paths+=("/usr/share/ansible/collections")

old_ifs="$IFS"; IFS=:
ANSIBLE_COLLECTIONS_PATH="$(
    for candidate in "${search_paths[@]}"; do
        [ -d "$candidate/ansible_collections" ] && printf '%s\n' "$candidate"
    done | paste -sd: -
)"
IFS="$old_ifs"
export ANSIBLE_COLLECTIONS_PATH

if ! collection_probe; then
    if [ "${REQUIRE_LINT_TOOLS:-0}" = "1" ] || [ "${CI:-}" = "true" ] || [ "${CI:-}" = "1" ]; then
        echo "error: the community.general collection is missing; searched ANSIBLE_COLLECTIONS_PATH=$ANSIBLE_COLLECTIONS_PATH" >&2
        echo "  (uid $(id -u), real home '${real_home:-unset}', repo root $repo_root)" >&2
        echo "  install it with:" >&2
        echo "  ansible-galaxy collection install -r infrastructure/ansible/requirements.yml" >&2
        echo "and see //:doctor for the tool census this lane depends on." >&2
        exit 1
    fi
    echo "WARN: community.general collection missing, skipping (set REQUIRE_LINT_TOOLS=1 to make this fatal)"
    exit 0
fi

cd "$here"
# Roles are resolved against this package's roles/ directory; an absolute path
# keeps that true from whatever directory the test stub started in.
export ANSIBLE_ROLES_PATH="$here/roles"

# Run ansible-lint with common options. The version goes into the log because
# the rules this lane applies travel with the release: the pinned requirements
# file fixes it, so a runner cannot lint against a stricter ruleset than the one
# a person cleared locally.
echo "Running ansible-lint $(ansible-lint --version 2>/dev/null | head -1)"
ansible-lint --config-file "$here/.ansible-lint" \
    --exclude .git --exclude node_modules --exclude venv "$@"

echo "Ansible linting completed successfully"
