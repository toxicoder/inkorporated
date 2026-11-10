#!/bin/bash
# Unit tests for tools/bazel/sh/gate_lib.sh: the runfiles-to-checkout walk and
# the split between nested-Bazel startup options and command options.
#
# Run with: bazelisk test //tools/bazel/sh/test:gate_lib_test

set -euo pipefail

HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
GATE_LIB="${HERE}/../gate_lib.sh"
failures=0

check() {
    local label="$1" status="$2"
    if [ "$status" = "0" ]; then
        echo "ok   - ${label}"
    else
        echo "FAIL - ${label} (exit ${status})" >&2
        failures=$((failures + 1))
    fi
}

[ -f "$GATE_LIB" ] || { echo "FATAL: ${GATE_LIB} is missing" >&2; exit 1; }

WORKDIR="$(mktemp -d)"
# Only test 7 needs a scratch tree outside WORKDIR, and only when WORKDIR's own
# ancestors hold a checkout, which would make the walk succeed for the wrong
# reason.
ORPHAN=""
cleanup() {
    rm -rf "$WORKDIR"
    if [ -n "$ORPHAN" ]; then
        rm -rf "$ORPHAN"
    fi
    return 0
}
trap cleanup EXIT

# 1. --output_base is a startup option and --lockfile_mode is a command option.
#    Bazel rejects either in the other's position with "Unknown startup
#    option", which is what took //:gate down once already.
status=0
(
    set -eu
    # shellcheck source=../gate_lib.sh
    source "$GATE_LIB"
    [ "${BAZEL_META[0]}" = "--output_base=${BAZEL_META_OUTPUT_BASE}" ]
    printf '%s\n' "${BAZEL_META[@]}" | grep -qv 'lockfile_mode'
    printf '%s\n' "${BAZEL_META_OPTS[@]}" | grep -q '^--lockfile_mode=off$'
    printf '%s\n' "${BAZEL_META_OPTS[@]}" | grep -qv 'output_base'
) || status=$?
check "startup options and command options stay in separate arrays" "$status"

# 2. The output base is overridable, so two nested runs can coexist.
status=0
(
    set -eu
    export BAZEL_META_OUTPUT_BASE=/tmp/some-other-base
    # shellcheck source=../gate_lib.sh
    source "$GATE_LIB"
    [ "${BAZEL_META[0]}" = "--output_base=/tmp/some-other-base" ]
) || status=$?
check "BAZEL_META_OUTPUT_BASE overrides the nested output base" "$status"

# 3. resolve_repo_root follows a symlinked script back to the checkout, which is
#    how every gate checker finds the repository from inside runfiles.
fake_repo="${WORKDIR}/checkout"
mkdir -p "${fake_repo}/.git" "${fake_repo}/tools/bazel/sh"
cp "$GATE_LIB" "${fake_repo}/tools/bazel/sh/gate_lib.sh"
cat >"${fake_repo}/tools/bazel/sh/caller.sh" <<'CALLER'
#!/bin/bash
set -eu
# Follow the runfiles symlink the way a Bazel-launched test does, then locate
# the library next to the script it really points at.
self="$(readlink -f "${BASH_SOURCE[0]}")"
here="$(cd "$(dirname "$self")" && pwd)"
# shellcheck source=gate_lib.sh
source "${here}/gate_lib.sh"
resolve_repo_root
printf '%s\n' "$REPO_ROOT"
CALLER
chmod +x "${fake_repo}/tools/bazel/sh/caller.sh"
ln -s "${fake_repo}/tools/bazel/sh/caller.sh" "${WORKDIR}/caller-link.sh"
status=0
resolved="$(bash "${WORKDIR}/caller-link.sh" 2>/dev/null)" || status=$?
if [ "$status" -eq 0 ] && [ "$resolved" = "$fake_repo" ]; then
    check "resolve_repo_root walks back to the checkout" 0
else
    check "resolve_repo_root walks back to the checkout (got '${resolved:-none}')" 1
fi

# 4. It refuses to guess when there is no checkout above the script.
mkdir -p "${WORKDIR}/orphan/pkg"
cp "$GATE_LIB" "${WORKDIR}/orphan/pkg/gate_lib.sh"
cat >"${WORKDIR}/orphan/pkg/caller.sh" <<'CALLER'
#!/bin/bash
set -eu
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gate_lib.sh
source "${here}/gate_lib.sh"
resolve_repo_root
printf '%s\n' "$REPO_ROOT"
CALLER
status=0
bash "${WORKDIR}/orphan/pkg/caller.sh" >/dev/null 2>&1 || status=$?
check "resolve_repo_root fails loudly outside a checkout" "$([ "$status" -ne 0 ] && echo 0 || echo 1)"

# 5. Inside a test action the nested base is the per-action scratch directory,
#    which Bazel creates and deletes, so two actions cannot share one base.
status=0
(
    set -eu
    export TEST_TMPDIR="${WORKDIR}/action-scratch"
    # shellcheck source=../gate_lib.sh
    source "$GATE_LIB"
    [ "${BAZEL_META[0]}" = "--output_base=${TEST_TMPDIR}/bazel-meta" ]
) || status=$?
check "a test action gets a nested base under TEST_TMPDIR" "$status"

# 6. Sourced by hand -- no TEST_TMPDIR, which is every run a person makes from
#    their own shell -- the base falls back to one per uid. A fixed shared path
#    would make two people on one host serialise on each other's workspace lock,
#    and Bazel holds that lock for the whole invocation.
status=0
# Each case sources the library in its own subshell, so the value read below is
# the one that subshell just computed, not the one test 2 exported into its own.
# shellcheck disable=SC2031
(
    set -eu
    unset TEST_TMPDIR
    # shellcheck source=../gate_lib.sh
    source "$GATE_LIB"
    uid="$(id -u)"
    [ "${BAZEL_META_OUTPUT_BASE}" = "/tmp/inkorporated-bazel-meta-${uid}" ]
    [ "${BAZEL_META[0]}" = "--output_base=/tmp/inkorporated-bazel-meta-${uid}" ]
    case "${BAZEL_META_OUTPUT_BASE}" in
        *"${uid}"*) ;;
        *) exit 1 ;;
    esac
) || status=$?
check "a hand-run source falls back to a per-uid output base" "$status"

# 7. resolve_repo_root refuses to guess, and names the path it started the walk
#    from. The scratch tree has to sit outside every checkout -- and the library
#    has to come from the checkout, not a copy -- because a copy's failure path
#    says nothing about the file the lane measures.
no_checkout_above() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -d "${dir}/.git" ]; then
            return 1
        fi
        dir="$(dirname "$dir")"
    done
    [ -d "/.git" ] && return 1
    return 0
}

orphan="${WORKDIR}/no-checkout"
mkdir -p "$orphan"
if ! no_checkout_above "$orphan"; then
    # TMPDIR itself is inside a checkout on this host: build the orphan
    # somewhere that is not, or the walk would succeed and prove nothing.
    orphan="/var/tmp/inkorporated-gate-lib-orphan-$$"
    mkdir -p "$orphan"
    ORPHAN="$orphan"
    no_checkout_above "$orphan" || {
        echo "FATAL: no scratch parent outside a checkout (checked /var/tmp too)" >&2
        exit 1
    }
fi
cat >"${orphan}/caller.sh" <<CALLER
#!/bin/bash
set -eu
# Source the shipped library in place: the walk has to fail in the file that
# ships, not in a copy of it laid down in the scratch tree.
source "${GATE_LIB}"
resolve_repo_root
printf '%s\n' "\$REPO_ROOT"
CALLER
status=0
stderr="$(bash "${orphan}/caller.sh" 2>&1 >/dev/null)" || status=$?
check "resolve_repo_root exits 1 with no checkout above it" \
    "$([ "$status" -eq 1 ] && echo 0 || echo 1)"
started_from="$(readlink -f "${orphan}/caller.sh")"
status=0
printf '%s\n' "$stderr" | grep -qF \
    "could not locate the repository root from ${started_from}" || status=$?
check "the failure names the path the walk started from" "$status"

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} gate_lib assertion(s) failed" >&2
    exit 1
fi
echo "SUCCESS: gate_lib.sh finds the checkout and splits the nested Bazel flags"
