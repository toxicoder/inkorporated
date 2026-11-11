#!/bin/bash
# Validates the Proxmox/AWS/GCP control-plane configuration with the terraform
# CLI in a throwaway copy of the tree.
#
# The copy matters: `terraform init` writes .terraform/ and
# .terraform.lock.hcl next to the configuration it reads, and this lane must
# not leave either of them in the checkout.
#
# Run it with: bazelisk test //infrastructure/terraform:terraform_validate
#
# This lane is tagged manual and host, so //:gate does not run it. It is red
# until someone decides which Proxmox provider this repository targets; see the
# comment on the target in BUILD.bazel.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TF_DIR="${REPO_ROOT}/infrastructure/terraform"

if ! command -v terraform >/dev/null 2>&1; then
    if [ "${REQUIRE_LINT_TOOLS:-0}" = "1" ] || [ "${CI:-}" = "1" ] || [ "${CI:-}" = "true" ]; then
        echo "Error: terraform is required for this lane. Install it or run:" >&2
        echo "  bazelisk run //:doctor" >&2
        exit 1
    fi
    echo "Warning: terraform missing; this lane reports nothing. Set REQUIRE_LINT_TOOLS=1 to make it fatal." >&2
    exit 0
fi

if [ ! -f "${TF_DIR}/main.tf" ]; then
    echo "Error: no terraform root found at ${TF_DIR}" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

cp -r "$TF_DIR" "${WORKDIR}/terraform"
cd "${WORKDIR}/terraform"

echo "terraform $(terraform version -json 2>/dev/null | sed -n 's/.*"terraform_version": "\(.*\)".*/\1/p')"

# Providers come from registry.terraform.io, so init needs egress. A sealed
# environment cannot tell a dead provider reference from a missing network, so
# say which one the operator is looking at.
if ! terraform init -backend=false -input=false -no-color; then
    cat >&2 <<'DIAG'

terraform init failed. The known defects in this tree, as measured on the
current tip:

  1. providers/proxmox/main.tf pins TelsaLabs/proxmox 0.6.0, which is not
     published on registry.terraform.io.
  2. providers.tf (root) pins telmate/proxmox 2.9.14 and uses
     pm_tls_insecure, while providers/proxmox/main.tf uses pm_insecure. The
     two blocks cannot both describe one provider.
  3. modules/network/main.tf declares proxmox_network_bridge,
     proxmox_network_dns and proxmox_firewall_rules, resource types none of
     the three candidate providers publishes.
  4. providers.tf refers to var.proxmox_api_token_id and
     var.proxmox_tls_insecure, neither of which variables.tf declares.
  5. providers/aws/main.tf and providers/gcp/main.tf configure their own
     providers, which makes them legacy modules, and main.tf calls both with
     count - Terraform rejects that combination outright.

Picking the provider is an infrastructure decision, so this lane stays tagged
manual until it is made. Fixing 4 and 5 is mechanical once 1 to 3 are settled.
DIAG
    exit 1
fi

terraform validate -no-color
echo "OK: ${TF_DIR} validates"
