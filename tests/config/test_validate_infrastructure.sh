#!/bin/bash

# Test validate_infrastructure.sh

# Test 1: Proxmox cluster active
echo "Testing Proxmox cluster active..."
echo "Cluster: active" > /tmp/pvecm_status
export PVECMD_STATUS_FILE="/tmp/pvecm_status"
if ./tests/config/validate_infrastructure.sh 2>&1 | grep -q "✅ Proxmox cluster is active"; then
  echo "Test 1 passed"
else
  echo "Test 1 failed"
  exit 1
fi

# Test 2: Proxmox node count
echo "Testing node count..."
echo "Nodes: 3" > /tmp/pvecm_status
if ./tests/config/validate_infrastructure.sh 2>&1 | grep -q "✅ Proxmox node count: 3"; then
  echo "Test 2 passed"
else
  echo "Test 2 failed"
  exit 1
fi

# Test 3: Synology directory exists
echo "Testing Synology directory exists..."
mkdir -p /tmp/volume1/k8s-backups
if ./tests/config/validate_infrastructure.sh 2>&1 | grep -q "✅ /volume1/k8s-backups directory exists"; then
  echo "Test 3 passed"
else
  echo "Test 3 failed"
  exit 1
fi

# Test 4: NFS exports check
echo "Testing NFS exports..."
echo "/volume1/k8s-backups 192.168.1.0/24(rw,sync)" > /tmp/exports
if ./tests/config/validate_infrastructure.sh 2>&1 | grep -q "✅ NFS exports include /volume1/k8s-backups"; then
  echo "Test 4 passed"
else
  echo "Test 4 failed"
  exit 1
fi

# Test 5: LAN subnet permissions
echo "Testing LAN subnet permissions..."
echo "/volume1/k8s-backups 192.168.1.0/24(rw,sync)" > /tmp/exports
if ./tests/config/validate_infrastructure.sh 2>&1 | grep -q "✅ LAN subnet 192.168.1.0/24 has permissions in exports"; then
  echo "Test 5 passed"
else
  echo "Test 5 failed"
  exit 1
fi

echo "All tests passed"