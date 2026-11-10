#!/bin/bash
# The tool census. Two halves: the image build has to keep declaring the tools
# the devcontainer promises (apt packages, npm globals, pip tools, the ArgoCD
# install and its architecture mapping, the feature list and its install order),
# and the tools the gate itself shells out to have to answer when asked.
#
# Run it with: bazelisk test //.devcontainer/scripts/tests:test_tools
#
# Nothing here downloads anything: the ArgoCD download was the old test, and it
# could only ever pass because `curl || echo` swallowed every failure. What is
# asserted instead is the architecture-to-URL decision the Dockerfile makes, by
# running that decision, plus a census that fails with the install command when
# a tool is gone.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../../.." && pwd)"
DEVCONTAINER="${REPO_ROOT}/.devcontainer"
DOCKERFILE="${DEVCONTAINER}/Dockerfile"
DEVCONTAINER_JSON="${DEVCONTAINER}/devcontainer.json"
TARGET="bazelisk test //.devcontainer/scripts/tests:test_tools"

failures=0

require_tool() {
    local tool="$1" install="$2"
    command -v "$tool" >/dev/null 2>&1 || {
        echo "FAIL - ${tool} is required by this lane; install it with: ${install}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    }
}

for required in "$DOCKERFILE" "$DEVCONTAINER_JSON"; do
    if [ ! -f "$required" ]; then
        echo "FAIL - expected file is missing: ${required}" >&2
        echo "       re-run with: ${TARGET}" >&2
        exit 1
    fi
done

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
# 1. The runtime census. Each of these is something the devcontainer tooling or
#    this gate shells out to, so a missing one is a broken host, not a skip.
#    node, npm, argocd and cline are deliberately absent from this list: they
#    are properties of the image the Dockerfile builds, not of a checkout, so
#    section 2 asserts the build still declares them instead of this section
#    probing a host that has no reason to carry them.
# ---------------------------------------------------------------------------
REQUIRED_TOOLS=(
    "bash|apt-get install -y bash"
    "git|apt-get install -y git"
    "curl|apt-get install -y curl"
    "python3|apt-get install -y python3"
    "jq|apt-get install -y jq"
    "shellcheck|apt-get install -y shellcheck"
    "yamllint|apt-get install -y yamllint"
)

for entry in "${REQUIRED_TOOLS[@]}"; do
    tool="${entry%%|*}"
    install="${entry#*|}"
    require_tool "$tool" "$install"
    # Capture the whole banner before trimming: piping into head lets a tool die
    # on SIGPIPE, and pipefail would read that as the tool being broken.
    if probe="$("$tool" --version 2>&1)"; then
        ok "${tool} answers --version (${probe%%$'\n'*})"
    else
        fail "${tool} is on PATH but --version failed" \
            "install it again with: ${install}"
    fi
done

# ---------------------------------------------------------------------------
# 2. The image build still declares every tool the devcontainer is documented
#    to provide. Dropping one from the Dockerfile fails here, not on the first
#    person who reaches for it inside a container.
# ---------------------------------------------------------------------------
APT_TOOLS=(yamllint clang-format coreutils python3-pip curl ca-certificates gnupg)
NPM_GLOBALS=(eslint prettier cline)
PIP_TOOLS=(black flake8 yapf)

missing_apt=""
for pkg in "${APT_TOOLS[@]}"; do
    if ! grep -qE "(^|[[:space:]\\\\])${pkg}([[:space:]\\\\]|[[:space:]]*\\\\|$)" "$DOCKERFILE"; then
        missing_apt="${missing_apt} ${pkg}"
    fi
done
if [ -z "$missing_apt" ]; then
    ok "the image build installs all ${#APT_TOOLS[@]} apt tools (${APT_TOOLS[*]})"
else
    fail "the image build no longer installs:${missing_apt}" \
        "add them back to the apt-get install line in the Dockerfile"
fi

npm_line="$(grep -E 'npm install -g' "$DOCKERFILE" | head -1)"
if [ -z "$npm_line" ]; then
    fail "the image build has no npm global install step" \
        "the container is documented to ship: ${NPM_GLOBALS[*]}"
else
    missing_npm=""
    for pkg in "${NPM_GLOBALS[@]}"; do
        if ! printf '%s\n' "$npm_line" | grep -qE "(^|[[:space:]])${pkg}([[:space:]]|$)"; then
            missing_npm="${missing_npm} ${pkg}"
        fi
    done
    if [ -z "$missing_npm" ]; then
        ok "the image build installs the npm globals (${NPM_GLOBALS[*]})"
    else
        fail "the npm global step is missing:${missing_npm}" \
            "step: ${npm_line}"
    fi
fi

# Node itself comes from NodeSource, and every npm global above depends on it.
if grep -q 'deb\.nodesource\.com/setup_lts\.x' "$DOCKERFILE" \
    && grep -qE 'apt-get install -y nodejs' "$DOCKERFILE"; then
    ok "the image build installs node from NodeSource before the npm globals"
else
    fail "the image build no longer installs node from NodeSource" \
        "eslint, prettier and cline cannot install without it"
fi

pip_line="$(grep -E 'pip3? install' "$DOCKERFILE" | head -1)"
if [ -z "$pip_line" ]; then
    fail "the image build has no pip install step" \
        "the container is documented to ship: ${PIP_TOOLS[*]}"
else
    missing_pip=""
    for pkg in "${PIP_TOOLS[@]}"; do
        if ! printf '%s\n' "$pip_line" | grep -qE "(^|[[:space:]])${pkg}([[:space:]]|$)"; then
            missing_pip="${missing_pip} ${pkg}"
        fi
    done
    if [ -z "$missing_pip" ]; then
        ok "the image build installs the python tools (${PIP_TOOLS[*]})"
    else
        fail "the pip step is missing:${missing_pip}" "step: ${pip_line}"
    fi
fi

# A base image on :latest makes every container build a different build.
base_image="$(awk '$1 == "FROM" { print $2; exit }' "$DOCKERFILE")"
case "$base_image" in
    ""|*:latest)
        fail "the image build is not pinned to a tagged base image" \
            "FROM ${base_image:-nothing}"
        ;;
    *:*)
        ok "the image build pins its base image (${base_image})"
        ;;
    *)
        fail "the image build has an untagged base image" "FROM ${base_image}"
        ;;
esac

# ---------------------------------------------------------------------------
# 3. ArgoCD: run the Dockerfile's own architecture-to-URL decision. The old test
#    downloaded the binary and then `|| echo` swallowed whatever happened, so a
#    broken mapping still passed. What matters is the decision, and it is
#    executable, so it is executed.
# ---------------------------------------------------------------------------
SELECTOR="${WORKDIR}/select-arch.sh"
{
    echo 'set -eu'
    echo 'ARCH="$1"'
    sed -n '/if \[ "\$ARCH" = /,/^[[:space:]]*fi/p' "$DOCKERFILE" \
        | sed -e 's/\\$//' -e 's/^[[:space:]]*&&[[:space:]]*//' -e 's/\burl=/selected_url=/'
    echo 'printf "%s\n" "$selected_url"'
} >"$SELECTOR"

if ! "$BASH_PATH" -n "$SELECTOR"; then
    fail "could not extract the ArgoCD architecture decision from the Dockerfile" \
        "the RUN block no longer looks like if [ \"\$ARCH\" = ... ]"
else
    amd64_url="$("$BASH_PATH" "$SELECTOR" x86_64 2>/dev/null)" || amd64_url=""
    aarch64_url="$("$BASH_PATH" "$SELECTOR" aarch64 2>/dev/null)" || aarch64_url=""
    arm64_url="$("$BASH_PATH" "$SELECTOR" arm64 2>/dev/null)" || arm64_url=""

    case "$amd64_url" in
        *argocd-linux-amd64) ok "x86_64 selects the amd64 ArgoCD binary" ;;
        *) fail "x86_64 does not select an amd64 ArgoCD binary" "selected: ${amd64_url:-nothing}" ;;
    esac

    for arch in aarch64 arm64; do
        selected="${amd64_url}"
        [ "$arch" = "aarch64" ] && selected="${aarch64_url}"
        [ "$arch" = "arm64" ] && selected="${arm64_url}"
        case "$selected" in
            *argocd-linux-arm64) ok "${arch} selects the arm64 ArgoCD binary" ;;
            *) fail "${arch} does not select an arm64 ArgoCD binary" "selected: ${selected:-nothing}" ;;
        esac
    done

    unsupported_out="$("$BASH_PATH" "$SELECTOR" riscv64 2>&1)" && unsupported_status=0 \
        || unsupported_status=$?
    if [ "$unsupported_status" != "0" ] \
        && printf '%s' "$unsupported_out" | grep -qF 'Unsupported architecture'; then
        ok "an unsupported architecture stops the build instead of fetching a wrong binary"
    else
        fail "an unsupported architecture is not rejected by the ArgoCD step" \
            "exit ${unsupported_status}, output: ${unsupported_out}"
    fi

    for url in "$amd64_url" "$aarch64_url"; do
        if printf '%s' "$url" | grep -qE '^https://github\.com/argoproj/argo-cd/releases/'; then
            ok "the ArgoCD download comes from the upstream release host"
        else
            fail "the ArgoCD download URL is not the upstream release host" \
                "url: ${url}"
        fi
    done
fi

# ---------------------------------------------------------------------------
# 4. devcontainer.json features: the tools that do not come from the Dockerfile
#    come from features, and every feature needs its place in the install order
#    or the container builds them in an arbitrary sequence.
# ---------------------------------------------------------------------------
if ! jq -e . "$DEVCONTAINER_JSON" >/dev/null 2>&1; then
    fail "devcontainer.json is not valid JSON" \
        "the devcontainer CLI refuses the file, so no container starts at all"
    echo "FAILURE: ${failures} tool-census assertion(s) failed" >&2
    echo "re-run with: ${TARGET}" >&2
    exit 1
fi
ok "devcontainer.json parses as JSON"

feature_count="$(jq '.features | length' "$DEVCONTAINER_JSON")"
if [ "$feature_count" -ge 3 ]; then
    ok "devcontainer.json requests ${feature_count} features"
else
    fail "devcontainer.json requests too few features" "count: ${feature_count}"
fi

for feature in node terraform kubectl-helm-minikube; do
    if jq -e --arg needle "/${feature}:1" '.features | keys | map(index($needle) != null) | any' \
        "$DEVCONTAINER_JSON" >/dev/null; then
        ok "the ${feature} feature is requested"
    else
        fail "the ${feature} feature is no longer requested" \
            "features: $(jq -c '.features | keys' "$DEVCONTAINER_JSON")"
    fi
done

for key in tflint terragrunt; do
    if jq -e --arg key "$key" '
            .features | to_entries[]
            | select(.key | contains("terraform"))
            | .value | has($key)
        ' "$DEVCONTAINER_JSON" >/dev/null; then
        ok "the terraform feature pins ${key}"
    else
        fail "the terraform feature no longer requests ${key}"
    fi
done

unordered="$(
    jq -r '
        . as $root
        | [ .features | keys[]
            | . as $f
            | ([ $root.overrideFeatureInstallOrder[]? as $o
                 | select($f | startswith($o)) ] | length) as $hits
            | select($hits == 0)
            | $f ]
        | join(" ")
    ' "$DEVCONTAINER_JSON"
)"
if [ -z "${unordered//[[:space:]]/}" ]; then
    ok "every feature has an entry in overrideFeatureInstallOrder"
else
    fail "features missing from overrideFeatureInstallOrder: ${unordered}" \
        "without an order the features install in an arbitrary sequence"
fi

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} tool-census assertion(s) failed" >&2
    echo "re-run with: ${TARGET}" >&2
    exit 1
fi

echo "SUCCESS: the gate tools answer, the image build still declares every tool," \
    "the ArgoCD architecture decision selects correctly, and the features stay ordered"
