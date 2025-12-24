# Inkorporated Homelab

A comprehensive, self-hosted, open-source internal work environment designed for homelab deployments. This project provides a complete, integrated solution that combines infrastructure automation, GitOps deployment, and a rich set of productivity and collaboration tools.

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
- **Environment Management**: Support for dev, staging, autopush, canary, and prod environments

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

## Documentation

The project includes comprehensive documentation in the `docs/` directory:

- **[Project Overview](docs/guides/overview.md)** - Executive summary and key features
- **[Architecture](docs/architecture/README.md)** - High-level architecture and system overview
- **[Implementation Status](docs/implementation/status.md)** - Current implementation progress and task tracking
- **[Documentation Index](docs/INDEX.md)** - Comprehensive documentation index

## Getting Started

1. Clone this repository
2. Configure your infrastructure settings in `infrastructure/terraform/terraform.tfvars`
3. Select and customize a deployment profile
4. Provision VMs with Terraform: `cd infrastructure/terraform && terraform apply`
5. Install k3s with Ansible: `cd infrastructure/ansible && ansible-playbook playbooks/k3s-install.yml`
6. Bootstrap ArgoCD and Gitea for GitOps workflow
7. Deploy services through GitOps

## File Management and Deletion

The development environment includes enhanced file management capabilities for working with infrastructure files. The devcontainer has been configured with:
- Core utilities for file operations (coreutils, findutils)
- Proper permissions for file deletion operations
- Support for GitOps workflows where file changes are managed through version control

When working with infrastructure files:
- Use GitOps principles: make changes through version control and deploy via ArgoCD
- For direct file operations, ensure proper permissions are set
- All file deletion operations should be performed through the appropriate Ansible roles or GitOps workflows

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

## Environment Support

This project supports multiple deployment environments:

- **dev** - Development environment
- **staging** - Staging environment  
- **autopush** - Automated push environment
- **canary** - Canary deployment environment
- **prod** - Production environment

Environment-specific configurations are managed through `config/environment-config.yaml` and can be selected via the `environment` Terraform variable.

## Services Overview

### Collaboration Services
- **Rocket.Chat**: Team chat platform
- **WorkAdventure**: 2D virtual office
- **Jitsi Meet**: Video conferencing
- **Coturn**: TURN/STUN server

### Productivity Services
- **AppFlowy**: Collaborative knowledge base
- **LinkWarden**: Bookmark manager
- **Homebox**: Inventory tracker
- **Home Assistant**: Smart home hub

### Remote Work Services
- **Kasm Workspaces**: Browser-based workspaces
- **Coder**: Cloud IDE workspaces

### AI Services
- **Ollama**: Local LLM runner
- **Open WebUI**: Ollama web interface
- **Langflow**: Visual LangChain builder
- **Kokoro TTS**: Local TTS server
- **Docling**: Document parsing server
- **SearXNG**: Metasearch engine
- **SurfSense**: AI research agent
- **Perplexica**: AI search engine

### Security Services
- **Vaultwarden**: Bitwarden-compatible password manager
- **HashiCorp Vault**: Secrets management

### Infrastructure Services
- **CloudNativePG**: PostgreSQL operator
- **Longhorn**: Distributed block storage
- **MinIO**: S3 object storage
- **Velero**: Backup/restore
- **ArgoCD**: GitOps engine
- **cert-manager**: TLS automation
- **MetalLB**: LoadBalancer provider

## How It Works

1. **Clone the Repository**: Developers clone this template repository
2. **Configure Settings**: Edit configuration files to specify:
   - Proxmox server details
   - Deployment profile (min, medium, recommended)
   - Services to deploy
   - Environment (dev, staging, prod, etc.)
3. **Deploy Infrastructure**: Run Terraform/Ansible to provision VMs and install k3s
4. **Bootstrap GitOps**: Deploy ArgoCD and Gitea for version control
5. **Manage Everything**: Use GitOps workflows for all infrastructure and application management

## Contributing

This project is open-source and welcomes contributions. Please see the contribution guidelines in the repository for more information.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please open an issue in the GitHub repository or contact the project maintainers.
