#!/bin/bash

# Configuration variables
EXPECTED_LAN_SUBNET="192.168.1.0/24"  # Update this to match your LAN subnet

# Validate Proxmox infrastructure
echo "Validating Proxmox infrastructure..."
# Check if Proxmox cluster is active
if pvecm status &> /dev/null; then
    echo " Proxmox cluster is active"
else
    echo "L Proxmox cluster is not active"
    exit 1
fi

# Check node count
node_count=$(pvecm status | grep -i 'nodes' | awk '{print $2}')
echo " Proxmox node count: $node_count"

# Check RAM
ram_total=$(free -m | awk '/Mem:/ {print $2}')
echo " Total RAM: ${ram_total}MB"

# Check CPU cores
cpu_cores=$(lscpu | grep 'CPU(s):' | head -1 | awk '{print $2}')
echo " CPU cores: ${cpu_cores}"

# Check storage (root filesystem)
storage=$(df -h / | awk 'NR==2 {print $2}')
echo " Root storage: ${storage}"

# Validate Synology NFS configuration
echo "Validating Synology NFS configuration..."
# Check if /volume1/k8s-backups exists
if [ -d "/volume1/k8s-backups" ]; then
    echo " /volume1/k8s-backups directory exists"
else
    echo "L /volume1/k8s-backups directory does not exist"
    exit 1
fi

# Check NFS service is running
if systemctl is-active nfs-server &> /dev/null; then
    echo " NFS service is running"
else
    echo "L NFS service is not running"
    exit 1
fi

# Check NFS exports for k8s-backups
if grep -q '/volume1/k8s-backups' /etc/exports; then
    echo " NFS exports include /volume1/k8s-backups"
else
    echo "L NFS exports do not include /volume1/k8s-backups"
    exit 1
fi

# Check for NFSv4.1 support in exports
if grep -q 'vers=4.1' /etc/exports; then
    echo " NFSv4.1 enabled in exports"
else
    echo "  NFSv4.1 not explicitly enabled in exports (check if NFSv4 is default)"
fi

# Check LAN subnet permissions
if grep -q "${EXPECTED_LAN_SUBNET}" /etc/exports; then
    echo " LAN subnet ${EXPECTED_LAN_SUBNET} has permissions in exports"
else
    echo "L LAN subnet ${EXPECTED_LAN_SUBNET} missing from exports"
    exit 1
fi

echo "Infrastructure validation passed!"