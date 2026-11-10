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
trap 'rm -rf "$WORKDIR"' EXIT

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

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} gate_lib assertion(s) failed" >&2
    exit 1
fi
echo "SUCCESS: gate_lib.sh finds the checkout and splits the nested Bazel flags"
