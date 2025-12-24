# Infrastructure Terraform Configuration

This directory contains the Terraform configuration for provisioning the Inkorporated homelab infrastructure.

## Overview

The infrastructure is provisioned using Terraform with the following components:
- Proxmox VMs for k3s cluster nodes
- Network configuration
- VM sizing and resource allocation

## Configuration

### Variables

The following variables can be configured:

- `proxmox_api_url` - URL of the Proxmox API
- `proxmox_api_token_id` - API token ID for Proxmox
- `proxmox_api_token_secret` - API token secret for Proxmox
- `environment` - Deployment environment (dev, staging, autopush, canary, prod)
- `deployment_profile` - VM sizing profile (min, medium, recommended)

### Environment Configuration

Environment-specific settings are defined in `config/environment-config.yaml`:

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

## Usage

### Setting up Terraform

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` to set your specific values

3. Initialize Terraform:
   ```bash
   terraform init
   ```

### Deploying Different Environments

To deploy to different environments:

```bash
# Deploy to dev environment
terraform apply -var="environment=dev"

# Deploy to staging environment
terraform apply -var="environment=staging"

# Deploy to production environment
terraform apply -var="environment=prod"
```

### Deployment Profiles

The deployment supports different VM sizing profiles:
- `min`: 1 control plane, 0 workers
- `medium`: 1 control plane, 1 worker  
- `recommended`: 1 control plane, 2 workers

## Files

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `outputs.tf` - Output definitions
- `terraform.tfvars.example` - Example variables file
