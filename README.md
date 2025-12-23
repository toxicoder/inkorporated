# inkorporated

A GitOps/Infrastructure as Code repository template for homelab deployments.

## Overview

This repository provides a comprehensive template for setting up a production-ready homelab infrastructure using GitOps principles. It combines Terraform, Ansible, and ArgoCD to automate the provisioning and deployment of a k3s-based Kubernetes cluster with all essential services.

The project is designed as a **template repository** that developers can clone, configure, and deploy to their homelabs. Once deployed, it provides a complete GitOps environment with version control, infrastructure automation, and application deployment capabilities.

## Key Features

- **GitOps Deployment**: Full infrastructure and application management through Git
- **Infrastructure as Code**: Terraform for VM provisioning, Ansible for k3s setup
- **Zero-trust Access**: Cloudflare Tunnel for secure external access
- **Centralized Authentication**: Authentik SSO/OIDC integration
- **Observability**: Prometheus, Grafana, and Loki stack
- **Storage Solutions**: Longhorn and NFS CSI driver
- **Backup & Recovery**: Velero with MinIO
- **Service Mesh**: Traefik with forward-auth middleware
- **Version Control**: Gitea instance for GitOps workflow
- **CI/CD**: Gitea runners for automated deployments

## Project Structure

```
.
├── apps/                     # Application deployments
│   └── shared/               # Shared applications
│       └── cloudflared/      # Cloudflare tunnel deployment
├── infrastructure/           # Infrastructure provisioning
│   ├── terraform/            # Terraform configurations
│   └── ansible/              # Ansible playbooks
├── kubernetes/               # Kubernetes manifests
│   ├── base/                 # Base configurations
│   ├── overlays/             # Environment-specific configurations
│   └── argocd/               # ArgoCD configurations
├── docs/                     # Documentation
└── memory-bank/              # Project documentation and context
```

## How It Works

1. **Clone the Repository**: Developers clone this template repository
2. **Configure Settings**: Edit configuration files to specify:
   - Proxmox server details
   - Deployment profile (min, medium, recommended)
   - Services to deploy
3. **Deploy Infrastructure**: Run Terraform/Ansible to provision VMs and install k3s
4. **Bootstrap GitOps**: Deploy ArgoCD and Gitea for version control
5. **Manage Everything**: Use GitOps workflows for all infrastructure and application management

## Deployment Profiles

### Min Profile
- 1 VM for control plane
- Minimal resource allocation
- Suitable for small homelabs
- Memory: 1024MB, Cores: 1, Disk: 10GB

### Medium Profile
- 1 VM for control plane
- 1 VM for worker node
- Balanced resource allocation
- Memory: 2048MB, Cores: 2, Disk: 20GB

### Recommended Profile
- 1 VM for control plane
- 2 VMs for worker nodes
- Production-ready resource allocation
- Memory: 4096MB, Cores: 4, Disk: 40GB

## Getting Started

1. Clone this repository
2. Configure your infrastructure settings in `infrastructure/terraform/terraform.tfvars`
3. Select and customize a deployment profile
4. Provision VMs with Terraform: `cd infrastructure/terraform && terraform apply`
5. Install k3s with Ansible: `cd infrastructure/ansible && ansible-playbook playbooks/k3s-install.yml`
6. Bootstrap ArgoCD and Gitea for GitOps workflow
7. Deploy services through GitOps

## Documentation

- [Infrastructure Setup Guide](docs/infrastructure_setup_guide.md)
- [Implementation Plan](docs/implementation_plan_updated.md)
- [Project Status](docs/inkorporated_project_status.md)
- [Technical Design](docs/technical_design_doc.md)
