#!/bin/bash
# Unit tests for //tests/config:validate_infrastructure. Each gate in that
# validator is exercised both ways: once with a fixture that satisfies it (the
# validator must exit 0 and print the matching "OK:" line) and once with a
# fixture that breaks it (the validator must exit non-zero and print the
# matching "FAIL:" line, and must not print the "OK:" line).
#
# Run with: bazelisk test //tests/config:test_validate_infrastructure
#
# The real host is never consulted: pvecm, systemctl, free, lscpu and df are
# fakes on a private PATH, and EXPORTS_FILE / BACKUP_VOLUME point at fixtures
# under mktemp -d. Every fixture value honours a caller-provided FAKE_* override,
# so sabotaging one fixture from outside (bazelisk test ... --test_env=
# FAKE_SYSTEMCTL=1) turns this lane red, which is what keeps it honest.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Bazel ships the validator next to this test through the data attribute, so the
# script directory is where it lives under runfiles as well as in the checkout.
VALIDATOR="${REPO_ROOT}/validate_infrastructure.sh"
TARGET="bazelisk test //tests/config:test_validate_infrastructure"

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

if [ ! -f "$VALIDATOR" ]; then
    echo "FATAL: ${VALIDATOR} is missing; the //tests/config:test_validate_infrastructure" >&2
    echo "       data attribute must ship validate_infrastructure.sh" >&2
    exit 1
fi

# The LAN subnet is a property of the validator, so it is read back rather than
# duplicated here: renaming or dropping the assignment has to fail this lane.
lan_subnet="$(sed -n 's/^EXPECTED_LAN_SUBNET="\([^"]*\)".*/\1/p' "$VALIDATOR" | head -1)"
if [ -z "$lan_subnet" ]; then
    echo "FATAL: ${VALIDATOR} declares no EXPECTED_LAN_SUBNET, so the LAN permission" >&2
    echo "       gate cannot be exercised; re-run with: ${TARGET}" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---------------------------------------------------------------------------
# Fake host: five executables on a private PATH, each driven by FAKE_* so one
# reading can be broken without touching the others.
# ---------------------------------------------------------------------------
BIN="${WORKDIR}/bin"
mkdir -p "$BIN" "${WORKDIR}/etc"

cat > "${BIN}/pvecm" <<'FAKE'
#!/bin/bash
[ "${FAKE_PVECM_STATUS:-0}" = "0" ] || exit "${FAKE_PVECM_STATUS}"
cat <<EOF
Status: final
Cluster information
-------------------
Cluster name:	toxic-pve
Nodes:		${FAKE_PVECM_NODES:-3}
EOF
FAKE

cat > "${BIN}/systemctl" <<'FAKE'
#!/bin/bash
if [ "${1:-}" = "is-active" ] && [ "${2:-}" = "nfs-server" ]; then
    [ "${FAKE_SYSTEMCTL:-0}" = "0" ] || exit "${FAKE_SYSTEMCTL}"
    echo active
fi
exit 0
FAKE

cat > "${BIN}/free" <<'FAKE'
#!/bin/bash
cat <<EOF
              total        used        free      shared
Mem:          ${FAKE_MEM_MB:-131072}     12345       99999           1
Swap:          16384           0       16384           0
EOF
FAKE

cat > "${BIN}/lscpu" <<'FAKE'
#!/bin/bash
cat <<EOF
Architecture:        x86_64
CPU(s):              ${FAKE_CPU_CORES:-8}
On-line CPU(s) list: 0-7
EOF
FAKE

cat > "${BIN}/df" <<'FAKE'
#!/bin/bash
cat <<EOF
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda2       ${FAKE_ROOT_SIZE:-916G}  120G  750G  14% /
EOF
FAKE

chmod 755 "${BIN}"/*

# Golden host readings. A caller-provided FAKE_* wins, which is how the lane is
# sabotaged from the outside to prove it is not vacuous.
GOLDEN_PVECM_STATUS="${FAKE_PVECM_STATUS:-0}"
GOLDEN_PVECM_NODES="${FAKE_PVECM_NODES:-3}"
GOLDEN_SYSTEMCTL="${FAKE_SYSTEMCTL:-0}"
GOLDEN_MEM_MB="${FAKE_MEM_MB:-131072}"
GOLDEN_CPU_CORES="${FAKE_CPU_CORES:-8}"
GOLDEN_ROOT_SIZE="${FAKE_ROOT_SIZE:-916G}"

golden_host() {
    export FAKE_PVECM_STATUS="$GOLDEN_PVECM_STATUS"
    export FAKE_PVECM_NODES="$GOLDEN_PVECM_NODES"
    export FAKE_SYSTEMCTL="$GOLDEN_SYSTEMCTL"
    export FAKE_MEM_MB="$GOLDEN_MEM_MB"
    export FAKE_CPU_CORES="$GOLDEN_CPU_CORES"
    export FAKE_ROOT_SIZE="$GOLDEN_ROOT_SIZE"
}

# Synology fixtures: the NFS export volume and the exports file that serves it.
VOLUME="${WORKDIR}/volume1/k8s-backups"
ABSENT_VOLUME="${WORKDIR}/volume1/absent-backups"
EXPORTS="${WORKDIR}/etc/exports"
mkdir -p "$VOLUME"

write_exports() {
    # write_exports <volume> <lan-subnet> <vers=4.1>, each yes or no. The knobs
    # are independent, so exactly one gate can be broken per run.
    local want_volume="$1" want_subnet="$2" want_vers="$3"
    local client="10.0.0.0/24"
    if [ "$want_subnet" = "yes" ]; then
        client="$lan_subnet"
    fi
    : > "$EXPORTS"
    if [ "$want_volume" = "yes" ]; then
        printf '%s %s(rw,sync,fsid=0,no_subtree_check)\n' "$VOLUME" "$client" >> "$EXPORTS"
    else
        printf '/volume1/guest %s(rw,sync)\n' "$client" >> "$EXPORTS"
    fi
    if [ "$want_vers" = "yes" ]; then
        printf '/volume1/unrelated %s(rw,sync,vers=4.1)\n' "$client" >> "$EXPORTS"
    fi
}

golden_host
export EXPORTS_FILE="$EXPORTS"
export BACKUP_VOLUME="$VOLUME"

status=0
out=""
run_validator() {
    status=0
    out="$(PATH="${BIN}:${PATH}" bash "$VALIDATOR" 2>&1)" || status=$?
}

expect_line() {
    local label="$1" line="$2"
    if grep -qxF -- "$line" <<<"$out"; then
        check "$label" 0
    else
        check "${label} (no such line: ${line})" 1
    fi
}

expect_no_line() {
    local label="$1" line="$2"
    if grep -qxF -- "$line" <<<"$out"; then
        check "${label} (unexpected line: ${line})" 1
    else
        check "$label" 0
    fi
}

expect_status() {
    local label="$1" want="$2"
    if { [ "$want" = "zero" ] && [ "$status" -eq 0 ]; } ||
       { [ "$want" = "nonzero" ] && [ "$status" -ne 0 ]; }; then
        check "$label" 0
    else
        check "${label} (got exit ${status})" 1
    fi
}

# ---------------------------------------------------------------------------
# 1. The whole set of gates passes against a complete fixture, and prints no
#    failure marker at all.
# ---------------------------------------------------------------------------
write_exports yes yes yes
run_validator
expect_status "a complete host exits 0" zero
if grep -q '^FAIL: ' <<<"$out"; then
    check "a complete host prints no FAIL: line" 1
else
    check "a complete host prints no FAIL: line" 0
fi

# Every informational reading has to come from the fake that feeds it, so
# deleting one of those pipelines is caught too.
expect_line "the node count comes from pvecm status" "OK: Proxmox node count: ${GOLDEN_PVECM_NODES}"
expect_line "the RAM total comes from free -m" "OK: Total RAM: ${GOLDEN_MEM_MB}MB"
expect_line "the core count comes from lscpu" "OK: CPU cores: ${GOLDEN_CPU_CORES}"
expect_line "the root filesystem size comes from df -h /" "OK: Root storage: ${GOLDEN_ROOT_SIZE}"

# Markers must stay plain ASCII: the emoji this lane shipped with were mangled
# into 0x05 bytes, and a grep can no longer match them.
if LC_ALL=C grep -q '[^ -~]' <<<"$out"; then
    check "the validator output is pure ASCII (found a non-ASCII byte)" 1
else
    check "the validator output is pure ASCII" 0
fi

# ---------------------------------------------------------------------------
# 2. Gate 1: pvecm status.
# ---------------------------------------------------------------------------
expect_line "gate 1 passes when pvecm status is 0" "OK: Proxmox cluster is active"

golden_host
export FAKE_PVECM_STATUS=1
run_validator
expect_status "gate 1 fails when pvecm status is non-zero" nonzero
expect_line "gate 1 names the inactive cluster" "FAIL: Proxmox cluster is not active"
expect_no_line "gate 1 does not also claim success" "OK: Proxmox cluster is active"

# ---------------------------------------------------------------------------
# 3. Gate 2: the Synology backup volume exists. The exports file still names it,
#    so only the directory test can fail this gate.
# ---------------------------------------------------------------------------
golden_host
export BACKUP_VOLUME="$ABSENT_VOLUME"
run_validator
expect_status "gate 2 fails when the backup volume is absent" nonzero
expect_line "gate 2 names the missing volume" "FAIL: ${ABSENT_VOLUME} directory does not exist"
expect_no_line "gate 2 does not also claim success" "OK: ${ABSENT_VOLUME} directory exists"

golden_host
export BACKUP_VOLUME="$VOLUME"
run_validator
expect_status "gate 2 passes when the backup volume exists" zero
expect_line "gate 2 names the backup volume it found" "OK: ${VOLUME} directory exists"

# ---------------------------------------------------------------------------
# 4. Gate 3: systemctl is-active nfs-server.
# ---------------------------------------------------------------------------
golden_host
export FAKE_SYSTEMCTL=3
run_validator
expect_status "gate 3 fails when nfs-server is not active" nonzero
expect_line "gate 3 names the stopped NFS service" "FAIL: NFS service is not running"
expect_no_line "gate 3 does not also claim success" "OK: NFS service is running"

golden_host
run_validator
expect_status "gate 3 passes when nfs-server is active" zero
expect_line "gate 3 reports a running NFS service" "OK: NFS service is running"

# ---------------------------------------------------------------------------
# 5. Gate 4: the exports file serves the backup volume.
# ---------------------------------------------------------------------------
golden_host
write_exports no yes yes
run_validator
expect_status "gate 4 fails when exports omit the backup volume" nonzero
expect_line "gate 4 names the missing export" "FAIL: NFS exports do not include ${VOLUME}"
expect_no_line "gate 4 does not also claim success" "OK: NFS exports include ${VOLUME}"

golden_host
write_exports yes yes yes
run_validator
expect_status "gate 4 passes when exports serve the backup volume" zero
expect_line "gate 4 reports the export" "OK: NFS exports include ${VOLUME}"

# ---------------------------------------------------------------------------
# 6. Gate 5: the LAN subnet holds permissions in the exports file.
# ---------------------------------------------------------------------------
golden_host
write_exports yes no yes
run_validator
expect_status "gate 5 fails when the LAN subnet is missing from exports" nonzero
expect_line "gate 5 names the missing subnet" "FAIL: LAN subnet ${lan_subnet} missing from exports"
expect_no_line "gate 5 does not also claim success" "OK: LAN subnet ${lan_subnet} has permissions in exports"

golden_host
write_exports yes yes yes
run_validator
expect_status "gate 5 passes when the LAN subnet is in exports" zero
expect_line "gate 5 reports the subnet permission" "OK: LAN subnet ${lan_subnet} has permissions in exports"

# ---------------------------------------------------------------------------
# 7. The NFSv4.1 line is advisory, as it has always been: its absence is a WARN
#    that must not change the exit status.
# ---------------------------------------------------------------------------
golden_host
write_exports yes yes no
run_validator
expect_status "the missing vers=4.1 note stays advisory" zero
expect_line "the missing vers=4.1 is reported" \
    "WARN: NFSv4.1 not explicitly enabled in exports (check if NFSv4 is default)"
expect_no_line "the missing vers=4.1 is not claimed as enabled" "OK: NFSv4.1 enabled in exports"

golden_host
write_exports yes yes yes
run_validator
expect_line "a vers=4.1 export is reported" "OK: NFSv4.1 enabled in exports"

if [ "$failures" -ne 0 ]; then
    echo "FAILURE: ${failures} validate_infrastructure assertion(s) failed" >&2
    echo "         re-run with: ${TARGET}" >&2
    exit 1
fi

echo "SUCCESS: all five validate_infrastructure gates pass and fail as the fixtures say;" \
    "re-run with: ${TARGET}"
