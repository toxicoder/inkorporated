# Ansible Automation

This directory contains all Ansible playbooks and configurations for automating the k3s installation and cluster setup.

## Overview

The Ansible playbooks are designed to automate the installation and configuration of k3s on the provisioned VMs. They handle:
- Initial system setup
- k3s installation and configuration
- Cluster initialization and node joining
- Post-installation configuration and validation

## Directory Structure

```
infrastructure/ansible/
├── playbooks/             # Main playbooks
│   ├── k3s-install.yml    # Install k3s on all nodes
│   ├── cluster-setup.yml  # Setup k3s cluster
│   └── post-setup.yml     # Post-installation tasks
├── inventory/             # Inventory files
│   ├── hosts.ini          # Static inventory
│   └── group_vars/        # Group variables
│       ├── control_plane.yml
│       └── worker_nodes.yml
├── roles/                 # Reusable roles
│   ├── k3s/               # k3s installation role
│   ├── cluster/           # Cluster management role
│   └── common/            # Common tasks role
├── vars/                  # Variable files
├── README.md              # This file
└── ansible.cfg            # Ansible configuration
```

## Getting Started

1. Configure inventory files with your VM IPs
2. Set required variables in group_vars
3. Run `ansible-playbook playbooks/k3s-install.yml`
4. Run `ansible-playbook playbooks/cluster-setup.yml`
5. Run `ansible-playbook playbooks/post-setup.yml`

## Playbooks

### k3s-install.yml
Installs k3s on all nodes with proper configuration.

### cluster-setup.yml
Initializes the k3s cluster and joins worker nodes.

### post-setup.yml
Performs post-installation configuration including:
- Installing required addons
- Configuring storage
- Setting up monitoring
- Configuring networking
