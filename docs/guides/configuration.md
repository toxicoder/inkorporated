---
layout: doc
---

# Configuration Management Guide

## Overview

This guide explains how to use the centralized configuration management system for the Inkorporated homelab infrastructure. The system replaces hardcoded domain references with configurable environment variables to make deployments more flexible across different environments.

## Configuration Structure

### Centralized Configuration

All configuration variables are now managed through the `inkorporated-config` ConfigMap in the `inkorporated` namespace. The configuration is loaded from `config/domain-config.yaml` and `config/environment-config.yaml`:

```yaml
# Domain configuration
DOMAIN_BASE: "example.com"
DOMAIN_WILDCARD: "*.example.com"

# Service-specific prefixes (loaded from config/domain-config.yaml)
SERVICE_WEBUI: "webui"
SERVICE_CHAT: "chat"
SERVICE_WORKADVENTURE: "workadventure"
SERVICE_JITSI: "jitsi"
# ... and so on for all services
```

### Environment Configuration

The `config/environment-config.yaml` file contains environment-specific settings for different deployment environments:

```yaml
environments:
  dev:
    domain:
      base: "dev.example.com"
      wildcard: "*.dev.example.com"
    description: "Development environment"
    priority: 1

  staging:
    domain:
      base: "staging.example.com"
      wildcard: "*.staging.example.com"
    description: "Staging environment"
    priority: 2

  autopush:
    domain:
      base: "autopush.example.com"
      wildcard: "*.autopush.example.com"
    description: "Autopush environment"
    priority: 3

  canary:
    domain:
      base: "canary.example.com"
      wildcard: "*.canary.example.com"
    description: "Canary environment"
    priority: 4

  prod:
    domain:
      base: "example.com"
      wildcard: "*.example.com"
    description: "Production environment"
    priority: 5

# Default environment (used if none specified)
default: "dev"
```

### Using domain-config.yaml

The `config/domain-config.yaml` file contains the base domain configuration and service subdomain mappings. This file should be modified to customize the domain setup for your environment:

```yaml
# Domain Configuration
# This file contains domain settings for the Inkorporated template
# Users can modify these values to customize their deployment

domain:
  base: "example.com"
  wildcard: "*.example.com"
  
# Service subdomains (will be constructed as service.example.com)
services:
  - name: "dashboard"
    subdomain: "dashboard"
  - name: "authentik"
    subdomain: "authentik"
  # ... and so on for all services
```

## How to Use

### 1. Environment Variables in Deployments

Services now reference configuration through environment variables:

```yaml
env:
  - name: DOMAIN_BASE
    valueFrom:
      configMapKeyRef:
        name: inkorporated-config
        key: DOMAIN_BASE
```

### 2. Domain References in Services

Hardcoded domains have been replaced with variable references:

```yaml
# Before (hardcoded)
value: "https://webui.example.com"

# After (configurable)
value: "https://webui.{{ .Env.DOMAIN_BASE }}"
```

### 3. Deployment Updates

To deploy with a different domain, simply update the `DOMAIN_BASE` value in the ConfigMap:

```bash
kubectl patch configmap inkorporated-config -n inkorporated -p '{"data":{"DOMAIN_BASE":"mydomain.com"}}'
```

## Services Updated

The following services have been updated to use the new configuration system:

- Traefik (ingress controller)
- Authentik (identity provider)
- Open WebUI
- Rocket.Chat
- WorkAdventure
- Vaultwarden
- Homepage
- Gitea
- Coturn
- Cloudflared

## Best Practices

1. **Namespace Organization**: All configuration is centralized in the `inkorporated` namespace
2. **Environment Variable Usage**: Services should reference configuration through environment variables
3. **Template Variables**: For ConfigMaps that support templating, use `{{ .Env.VARIABLE_NAME }}` syntax
4. **Environment Selection**: Use the `ENVIRONMENT` variable to select deployment environment
5. **Consistent Naming**: Use consistent naming conventions for configuration variables
6. **Backward Compatibility**: Existing deployments will continue to work with default values

## Testing Configuration Changes

To test configuration changes:

1. Update the ConfigMap with new values:
   ```bash
   kubectl edit configmap inkorporated-config -n inkorporated
   ```

2. Restart affected pods:
   ```bash
   kubectl rollout restart deployment/<deployment-name> -n <namespace>
   ```

3. Verify the changes are applied:
   ```bash
   kubectl get pods -n <namespace>
   ```

## Future Improvements

The configuration system can be extended to include:
- Additional environment-specific variables
- Service-specific configuration
- More complex templating for ConfigMaps
- Integration with external configuration management tools

## Environment Deployment Example

To deploy to different environments, use the following approach:

### Using Terraform with Environment Selection

```bash
# Set environment in terraform.tfvars or via command line
terraform apply -var="environment=staging"
```

### Switching Environments in Kubernetes

To switch environments in your deployments:

1. Update the ConfigMap to specify the environment:
   ```bash
   kubectl patch configmap inkorporated-config -n inkorporated -p '{"data":{"ENVIRONMENT":"staging"}}'
   ```

2. Restart affected pods to pick up the new configuration:
   ```bash
   kubectl rollout restart deployment/open-webui -n webui
   kubectl rollout restart deployment/authentik -n authentik
   ```

### Environment-Specific Domain Configuration

Each environment uses its own domain configuration:

- **dev**: `dev.example.com`
- **staging**: `staging.example.com`
- **autopush**: `autopush.example.com`
- **canary**: `canary.example.com`
- **prod**: `example.com`

The environment configuration is loaded from `config/environment-config.yaml` and automatically applied when deploying with the appropriate Terraform variables.

## Infrastructure Setup Guide

This guide provides detailed instructions for setting up the inkorporated homelab infrastructure using Terraform and Ansible.

### Overview

The infrastructure setup consists of two main components:
1. **Terraform**: Provisions VMs in Proxmox
2. **Ansible**: Installs and configures k3s, Gitea, ArgoCD, and GitOps components

### Prerequisites

#### Hardware Requirements
- Proxmox VE server with sufficient resources
- Minimum 4GB RAM per VM (for min profile)
- Minimum 20GB disk space per VM (for min profile)
- Network connectivity between Proxmox and target machines

#### Software Requirements
- Terraform 1.0+
- Ansible 2.10+
- SSH access to Proxmox server
- Properly configured Proxmox API credentials

### Setup Steps

#### 1. Terraform Infrastructure Provisioning

##### Configure Variables
Navigate to `infrastructure/terraform/` and create a `terraform.tfvars` file by copying the example:

```bash
cp infrastructure/terraform/terraform.tfvars.example infrastructure/terraform/terraform.tfvars
```

Edit the `terraform.tfvars` file with your specific values:

```hcl
# Proxmox Configuration
proxmox_api_url = "https://your-proxmox-server:8006/api2/json"
proxmox_api_token_id = "your-token-id"
proxmox_api_token_secret = "your-token-secret"

# Network Configuration
network_cidr = "192.168.1.0/24"
network_gateway = "192.168.1.1"
network_dns = "192.168.1.1"

# VM Configuration
vm_memory = 2048
vm_cores = 2
vm_sockets = 1
vm_disk_size = 20
vm_network_bridge = "vmbr0"
vm_iso_image = "local:iso/ubuntu-22.04.3-live-server-amd64.iso"

# VM Count Configuration (Profile-based)
control_plane_count = 1
worker_node_count = 1

# VM Naming
vm_name_prefix = "inkorporated"
vm_template_name = "k3s-template"

# Deployment Profile
deployment_profile = "recommended"

# Service Selection
enable_gitea = true
enable_argocd = true
enable_authentik = true
enable_traefik = true
enable_prometheus = true
enable_grafana = true
enable_loki = true
enable_longhorn = true
enable_velero = true
```

##### Select Deployment Profile
Choose from the available profiles:
- `min`: 1 control plane, 0 workers
- `medium`: 1 control plane, 1 worker
- `recommended`: 1 control plane, 2 workers

##### Apply Infrastructure
```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

#### 2. Ansible k3s Installation

##### Configure Inventory
Update `infrastructure/ansible/inventory/hosts.ini` with your actual VM IPs:

```ini
[control_plane]
control-plane-1 ansible_host=192.168.1.10

[worker_nodes]
worker-1 ansible_host=192.168.1.11
worker-2 ansible_host=192.168.1.12

[all:vars]
ansible_user=ubuntu
ansible_become=yes
ansible_become_method=sudo
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

##### Configure Variables
Set any additional variables in:
- `infrastructure/ansible/inventory/group_vars/control_plane.yml`
- `infrastructure/ansible/inventory/group_vars/worker_nodes.yml`

##### Run Playbooks
Execute the Ansible playbooks in sequence:

```bash
cd infrastructure/ansible

# Install k3s
ansible-playbook playbooks/k3s-install.yml

# Setup cluster
ansible-playbook playbooks/cluster-setup.yml

# Post-setup configuration
ansible-playbook playbooks/post-setup.yml

# Bootstrap GitOps environment (Gitea, ArgoCD, runners)
ansible-playbook playbooks/bootstrap-gitops.yml
```

### Deployment Profiles

#### Min Profile
- 1 VM for control plane
- Minimal resource allocation
- Suitable for small homelabs
- Memory: 1024MB, Cores: 1, Disk: 10GB

#### Medium Profile
- 1 VM for control plane
- 1 VM for worker node
- Balanced resource allocation
- Memory: 2048MB, Cores: 2, Disk: 20GB

#### Recommended Profile
- 1 VM for control plane
- 2 VMs for worker nodes
- Production-ready resource allocation
- Memory: 4096MB, Cores: 4, Disk: 40GB

### GitOps Workflow

After successful infrastructure setup, the system provides a complete GitOps workflow:

1. **Gitea**: Version control system for managing infrastructure and applications
2. **ArgoCD**: GitOps continuous delivery for Kubernetes applications
3. **Gitea Runners**: CI/CD runners for automated deployments

#### Using the GitOps Workflow

1. Access Gitea at `http://<gitea-ip>:3000`
2. Create repositories for your infrastructure and applications
3. Push your configurations to Git
4. ArgoCD will automatically deploy changes to your k3s cluster
5. Use Gitea runners for automated CI/CD pipelines

### Troubleshooting

#### Common Issues

1. **Proxmox API Connection Errors**
   - Verify API credentials and URL
   - Ensure API token has proper permissions
   - Check network connectivity

2. **SSH Connection Failures**
   - Verify SSH keys are configured
   - Ensure Ubuntu user has proper permissions
   - Check firewall settings

3. **k3s Installation Failures**
   - Check system requirements
   - Verify network connectivity
   - Review Ansible logs for detailed errors

#### Debugging Commands

```bash
# Check Terraform state
terraform state list

# Check Ansible inventory
ansible-inventory -i inventory/hosts.ini --list

# Check k3s status
systemctl status k3s

# Check k3s logs
journalctl -u k3s -f

# Check ArgoCD pods
kubectl get pods -n argocd

# Check Gitea service
kubectl get svc gitea -n default
```

### Next Steps

After successful infrastructure setup, you'll have a complete GitOps environment ready for use:

1. **Configure Services**: Enable/disable services through Terraform variables
2. **Deploy Applications**: Use ArgoCD to deploy applications through Git
3. **Version Control**: Manage all infrastructure and applications through Gitea
4. **CI/CD**: Automate deployments using Gitea runners
5. **Monitoring**: Use the built-in Prometheus, Grafana, and Loki stack
