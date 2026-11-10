#!/bin/bash
# The devcontainer test framework lane: it checks the test scripts themselves
# (shape, lint, and no silent skips) and it asserts what gpu-detect.sh actually
# does when a GPU is present, absent, and on every supported architecture.
#
# Run it with: bazelisk test //.devcontainer/scripts/tests:test_framework
#
# nvidia-smi and uname are stubbed on PATH inside a temp dir, so both GPU
# branches and all three architecture branches are exercised without a GPU and
# without a host that has the NVIDIA toolkit. No lane here skips anything: a
# missing shellcheck fails with the install command.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../../.." && pwd)"
DEVCONTAINER="${REPO_ROOT}/.devcontainer"
TESTS_DIR="${DEVCONTAINER}/scripts/tests"
GPU_DETECT="${DEVCONTAINER}/scripts/utilities/gpu-detect.sh"
TARGET="bazelisk test //.devcontainer/scripts/tests:test_framework"

failures=0

require_tool() {
    local tool="$1" install="$2"
    command -v "$tool" >/dev/null 2>&1 || {
        echo "FAIL - ${tool} is required by this lane; install it with: ${install}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    }
}

require_tool shellcheck "apt-get install -y shellcheck"

if [ ! -f "$GPU_DETECT" ]; then
    echo "FAIL - the GPU detector is missing: ${GPU_DETECT}" >&2
    echo "       re-run with: ${TARGET}" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

BASH_PATH="$(command -v bash)"

ok() {
    echo "ok   - $1"
}

fail() {
    local label="$1"
    shift
    echo "FAIL - ${label}" >&2
    for detail in "$@"; do
        echo "       ${detail}" >&2
    done
    echo "       re-run with: ${TARGET}" >&2
    failures=$((failures + 1))
}

# ---------------------------------------------------------------------------
# 1. Every test script in this package is a real bash test: it declares the
#    strict mode, lints clean, names the target to re-run, and cannot pass by
#    skipping. A guard that exits zero when its tool is missing is exactly the
#    test theatre this conversion removes, so it fails the lane here.
# ---------------------------------------------------------------------------
TEST_SCRIPTS=(
    test-env.sh
    test-file-utils.sh
    test-framework.sh
    test-mcp.sh
    test-tools.sh
)
TEST_TARGETS=(
    test_env
    test_file_utils
    test_framework
    test_mcp
    test_tools
)

if [ "${#TEST_SCRIPTS[@]}" -ne "${#TEST_TARGETS[@]}" ]; then
    fail "the script list and the target list disagree" \
        "add the new script to both lists"
fi

for index in "${!TEST_SCRIPTS[@]}"; do
    script="${TEST_SCRIPTS[$index]}"
    target="${TEST_TARGETS[$index]}"
    path="${TESTS_DIR}/${script}"

    if [ ! -f "$path" ]; then
        fail "${script} is missing from the tests package" \
            "expected: ${path}"
        continue
    fi

    if [ ! -x "$path" ]; then
        fail "${script} is not executable" \
            "Bazel's sh_test cannot run a non-executable src"
    else
        ok "${script} is executable"
    fi

    if [ "$(head -1 "$path")" = '#!/bin/bash' ]; then
        ok "${script} starts with the bash shebang"
    else
        fail "${script} does not start with '#!/bin/bash'" \
            "first line: $(head -1 "$path")"
    fi

    if head -25 "$path" | grep -qE '^set -euo pipefail$'; then
        ok "${script} runs under set -euo pipefail"
    else
        fail "${script} is missing 'set -euo pipefail' near the top"
    fi

    if syntax_out="$("$BASH_PATH" -n "$path" 2>&1)"; then
        ok "${script} parses"
    else
        fail "${script} has a syntax error" "${syntax_out}"
    fi

    if lint_out="$(shellcheck --severity=warning "$path" 2>&1)"; then
        ok "${script} is shellcheck clean at warning severity"
    else
        fail "${script} is not shellcheck clean" "${lint_out}"
    fi

    if grep -qF "bazelisk test //.devcontainer/scripts/tests:${target}" "$path"; then
        ok "${script} names ${target} as the target to re-run"
    else
        fail "${script} does not tell the reader which target to re-run" \
            "expected it to mention ${target}"
    fi

    offenders="$(awk '/[|][|][[:space:]]*(exit[[:space:]]+0|true)/ { print NR ": " $0 }' "$path")"
    if [ -z "$offenders" ]; then
        ok "${script} has no silent skip or swallowed failure"
    else
        fail "${script} passes by skipping: it swallows a failure" \
            "$offenders" \
            "a green gate must mean the tool really ran"
    fi

    if grep -qE 'sed[[:space:]]+-[A-Za-z]*i|chmod[[:space:]]+[0-9]+[[:space:]]+"?\$\{?REPO_ROOT' "$path"; then
        fail "${script} mutates files in the checkout" \
            "write into mktemp instead"
    else
        ok "${script} does not rewrite tracked files"
    fi

    if grep -qE 'rm[[:space:]]+-rf[[:space:]]+"\$\{?WORKDIR' "$path" \
        && ! grep -qE 'trap .*EXIT' "$path"; then
        fail "${script} deletes a temp tree without a cleanup trap"
    else
        ok "${script} cleans its temp tree up on exit"
    fi
done

# ---------------------------------------------------------------------------
# 2. gpu-detect.sh: syntax, lint, and the behaviour of both GPU branches and
#    all three architecture branches, driven by stubs on PATH.
# ---------------------------------------------------------------------------
if ! "$BASH_PATH" -n "$GPU_DETECT"; then
    fail "gpu-detect.sh has a syntax error"
else
    ok "gpu-detect.sh parses"
fi

if lint_out="$(shellcheck --severity=warning "$GPU_DETECT" 2>&1)"; then
    ok "gpu-detect.sh is shellcheck clean at warning severity"
else
    fail "gpu-detect.sh is not shellcheck clean" "${lint_out}"
fi

STUB_BIN="${WORKDIR}/bin"
EMPTY_BIN="${WORKDIR}/empty"
MARKER="${WORKDIR}/nvidia-ran"
mkdir -p "$STUB_BIN" "$EMPTY_BIN"

# The only binaries the detector reaches for are uname and, when present,
# nvidia-smi. Everything else it prints comes from builtins, so a PATH of these
# two directories makes both branches deterministic.
cat >"${STUB_BIN}/uname" <<STUB
#!/bin/bash
echo "\${STUB_ARCH:-x86_64}"
STUB
chmod 755 "${STUB_BIN}/uname"

run_detector() {
    local arch="$1"
    env -i PATH="${STUB_BIN}:${EMPTY_BIN}" HOME="${WORKDIR}" STUB_ARCH="$arch" \
        "$BASH_PATH" "$GPU_DETECT" 2>&1
}

no_gpu_output=""
if ! no_gpu_output="$(run_detector x86_64)"; then
    fail "gpu-detect.sh failed on a host with no GPU" \
        "the container bootstrap must not die over a missing GPU"
fi

if [ ! -e "$MARKER" ]; then
    ok "with no nvidia-smi on PATH the detector did not invoke one"
else
    fail "the detector ran nvidia-smi when none is on PATH"
fi

case "$no_gpu_output" in
    *"Dev Container GPU Setup Assistant"*)
        ok "the detector prints its header before anything else"
        ;;
    *)
        fail "the detector is missing its header" "output: ${no_gpu_output}"
        ;;
esac

case "$no_gpu_output" in
    *"No NVIDIA GPU detected"*)
        ok "with no GPU it reports the no-GPU branch"
        ;;
    *)
        fail "with no GPU it did not report the no-GPU branch" \
            "output: ${no_gpu_output}"
        ;;
esac

case "$no_gpu_output" in
    *"Setup Complete"*)
        ok "the no-GPU run still reaches Setup Complete"
        ;;
    *)
        fail "the no-GPU run never reaches Setup Complete" \
            "output: ${no_gpu_output}"
        ;;
esac

# Now put a nvidia-smi stub on PATH: the other branch must run it, not just
# claim a GPU, and must still succeed.
cat >"${STUB_BIN}/nvidia-smi" <<STUB
#!/bin/bash
echo "STUB-NVIDIA-SMI-CALLED"
: >"${MARKER}"
STUB
chmod 755 "${STUB_BIN}/nvidia-smi"

gpu_output=""
if ! gpu_output="$(run_detector x86_64)"; then
    fail "gpu-detect.sh failed with an NVIDIA GPU present" \
        "the container bootstrap must not die over GPU setup"
fi

if [ -e "$MARKER" ]; then
    ok "with nvidia-smi on PATH the detector actually called it"
else
    fail "the detector reported a GPU without calling nvidia-smi"
fi

case "$gpu_output" in
    *"STUB-NVIDIA-SMI-CALLED"*)
        ok "the GPU branch surfaces the nvidia-smi output"
        ;;
    *)
        fail "the GPU branch never ran nvidia-smi" "output: ${gpu_output}"
        ;;
esac

case "$gpu_output" in
    *"NVIDIA GPU detected"*)
        if [ "${gpu_output#*No NVIDIA GPU detected}" = "$gpu_output" ]; then
            ok "the GPU branch reports the GPU-found path"
        else
            fail "the GPU branch took the no-GPU path while nvidia-smi answered"
        fi
        ;;
    *)
        fail "the GPU branch is missing its detection line" "output: ${gpu_output}"
        ;;
esac

case "$gpu_output" in
    *"Setup Complete"*) ok "the GPU run reaches Setup Complete" ;;
    *) fail "the GPU run never reaches Setup Complete" "output: ${gpu_output}" ;;
esac

rm -f "${STUB_BIN}/nvidia-smi"

# Architecture branches: the detector picks its advice from uname -m, and an
# unknown machine must still get a usable answer rather than an error.
declare -A ARCH_EXPECT=(
    [x86_64]="Intel/AMD (x86_64) detected"
    [aarch64]="Apple Silicon (ARM64) detected"
    [arm64]="Apple Silicon (ARM64) detected"
    [riscv64]="Unknown architecture: riscv64"
)
for arch in x86_64 aarch64 arm64 riscv64; do
    expected="${ARCH_EXPECT[$arch]}"
    output=""
    if ! output="$(run_detector "$arch")"; then
        fail "gpu-detect.sh exited non-zero on ${arch}"
        continue
    fi
    case "$output" in
        *"Current architecture: ${arch}"*)
            ok "the detector reports the machine uname reports (${arch})"
            ;;
        *)
            fail "the detector did not report ${arch} as the current architecture" \
                "output: ${output}"
            ;;
    esac
    case "$output" in
        *"$expected"*)
            ok "the ${arch} branch prints the matching guidance"
            ;;
        *)
            fail "the ${arch} branch did not print '${expected}'" \
                "output: ${output}"
            ;;
    esac
done

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} framework assertion(s) failed" >&2
    echo "re-run with: ${TARGET}" >&2
    exit 1
fi

echo "SUCCESS: all five test scripts are strict, linted, self-naming, and skip-free;" \
    "gpu-detect.sh handles GPU present, GPU absent, and four architectures"
