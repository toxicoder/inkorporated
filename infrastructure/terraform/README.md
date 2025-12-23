# Terraform Infrastructure Provisioning

This directory contains all Terraform configurations for provisioning the homelab infrastructure.

## Overview

The Terraform configurations are designed to provision VMs in a Proxmox environment for the k3s-based Kubernetes cluster. The configurations support different deployment profiles (min, medium, recommended) to accommodate various hardware capabilities.

## Directory Structure

```
infrastructure/terraform/
├── main.tf              # Main configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── providers.tf         # Provider configurations
├── modules/             # Reusable modules
│   ├── vm/              # VM provisioning module
│   └── network/         # Network configuration module
├── profiles/            # Deployment profiles
│   ├── min/
│   ├── medium/
│   └── recommended/
└── README.md            # This file
```

## Deployment Profiles

### Min Profile
- 1 VM for control plane
- Minimal resource allocation
- Suitable for small homelabs

### Medium Profile
- 1 VM for control plane
- 1 VM for worker node
- Balanced resource allocation

### Recommended Profile
- 1 VM for control plane
- 2 VMs for worker nodes
- Production-ready resource allocation

## Getting Started

1. Configure your Proxmox credentials
2. Select and customize a deployment profile
3. Run `terraform init`
4. Run `terraform plan` to review changes
5. Run `terraform apply` to provision infrastructure

## Variables

See `variables.tf` for all configurable options.

## Outputs

See `outputs.tf` for all output values.
