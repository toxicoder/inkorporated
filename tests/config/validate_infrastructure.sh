#!/bin/bash
# Validates the Proxmox node and the Synology NFS export the k8s backups land
# on. This is a host-only lane: it asks the live cluster and the live exports
# file, so it is tagged host + manual and //:gate never runs it.
#
# Run it on the Proxmox node with:
#   bazelisk test //tests/config:validate_infrastructure
#
# Success and failure markers are plain ASCII (OK: / FAIL:) so a grep can match
# them from any locale, and so //tests/config:test_validate_infrastructure can
# assert on them. The three host inputs below default to the real paths, so the
# script behaves identically on the node; the unit test overrides them together
# with fake pvecm/systemctl/free/lscpu/df on a private PATH.

set -euo pipefail

# Configuration variables
EXPECTED_LAN_SUBNET="192.168.1.0/24"  # Update this to match your LAN subnet

# Host inputs, injectable for the unit test. Defaults are the real host paths.
EXPORTS_FILE="${EXPORTS_FILE:-/etc/exports}"
BACKUP_VOLUME="${BACKUP_VOLUME:-/volume1/k8s-backups}"

ok() {
    echo "OK: $1"
}

# fail always aborts: a validator that kept going after a missing backup volume
# would report a node it already knows is broken.
fail() {
    echo "FAIL: $1"
    exit 1
}

# report prints an informational host reading. These four readings never gated
# before this conversion, so an unavailable one is reported and not fatal.
report() {
    local label="$1" tool="$2" value="$3"
    value="$(printf '%s' "$value" | tr '\n' ' ')"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    if [ -n "$value" ]; then
        ok "${label}: ${value}"
    else
        echo "WARN: ${label}: unavailable from ${tool} output"
    fi
}

echo "Validating Proxmox infrastructure..."

# Check if Proxmox cluster is active
if pvecm status >/dev/null 2>&1; then
    ok "Proxmox cluster is active"
else
    fail "Proxmox cluster is not active"
fi

# Check node count
node_count="$(pvecm status | awk 'tolower($0) ~ /nodes/ && !seen++ {print $2}')" || node_count=""
report "Proxmox node count" pvecm "$node_count"

# Check RAM
ram_total="$(free -m | awk '/Mem:/ {print $2}')" || ram_total=""
report "Total RAM" free "${ram_total:+${ram_total}MB}"

# Check CPU cores
cpu_cores="$(lscpu | awk '/CPU\(s\):/ && !seen++ {print $2}')" || cpu_cores=""
report "CPU cores" lscpu "$cpu_cores"

# Check storage (root filesystem)
storage="$(df -h / | awk 'NR==2 {print $2}')" || storage=""
report "Root storage" df "$storage"

# Validate Synology NFS configuration
echo "Validating Synology NFS configuration..."

# Check if the backup volume exists
if [ -d "$BACKUP_VOLUME" ]; then
    ok "${BACKUP_VOLUME} directory exists"
else
    fail "${BACKUP_VOLUME} directory does not exist"
fi

# Check NFS service is running
if systemctl is-active nfs-server >/dev/null 2>&1; then
    ok "NFS service is running"
else
    fail "NFS service is not running"
fi

# Check NFS exports for the backup volume
if [ -f "$EXPORTS_FILE" ] && grep -q -- "$BACKUP_VOLUME" "$EXPORTS_FILE"; then
    ok "NFS exports include ${BACKUP_VOLUME}"
else
    fail "NFS exports do not include ${BACKUP_VOLUME}"
fi

# Check for NFSv4.1 support in exports. Advisory only: some appliances serve
# NFSv4.1 by default without naming it in the exports file.
if [ -f "$EXPORTS_FILE" ] && grep -q 'vers=4.1' "$EXPORTS_FILE"; then
    ok "NFSv4.1 enabled in exports"
else
    echo "WARN: NFSv4.1 not explicitly enabled in exports (check if NFSv4 is default)"
fi

# Check LAN subnet permissions
if [ -f "$EXPORTS_FILE" ] && grep -q "${EXPECTED_LAN_SUBNET}" "$EXPORTS_FILE"; then
    ok "LAN subnet ${EXPECTED_LAN_SUBNET} has permissions in exports"
else
    fail "LAN subnet ${EXPECTED_LAN_SUBNET} missing from exports"
fi

echo "Infrastructure validation passed!"
