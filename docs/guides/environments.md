---
layout: doc
---

# Environment Implementation Guide

This document provides guidance on implementing and managing multiple environments (dev, staging, autopush, prod) for the Inkorporated homelab infrastructure.

## Overview

The Inkorporated homelab supports multiple deployment environments to enable proper development, testing, and production workflows. The supported environments are:

- **dev** - Development environment
- **staging** - Staging environment  
- **autopush** - Automated push environment
- **canary** - Canary deployment environment
- **prod** - Production environment

## Environment Configuration

Environment-specific configurations are managed through the `config/environment-config.yaml` file which defines the domains and settings for each environment.

## Kubernetes Manifest Updates

All Kubernetes manifests have been updated to support environment-specific deployments by:

1. Using environment variables in ConfigMaps and Deployments
2. Implementing proper namespace separation
3. Configuring domain routing for each environment

## Infrastructure Support

### Terraform

The Terraform configuration now includes an `environment` variable that can be set during deployment:

```hcl
variable "environment" {
  description = "Deployment environment (dev, staging, autopush, canary, prod)"
  type        = string
  default     = "dev"
}
```

### Ansible

The Ansible bootstrap playbook now supports environment-specific deployments through the `ENVIRONMENT` environment variable:

```yaml
vars:
  environment: "{{ lookup('env', 'ENVIRONMENT') | default('dev') }}"
```

## Environment-Specific Domain Configuration

Each environment uses its own domain structure:
- **dev**: `dev.example.com` and `*.dev.example.com`
- **staging**: `staging.example.com` and `*.staging.example.com`
- **autopush**: `autopush.example.com` and `*.autopush.example.com`
- **canary**: `canary.example.com` and `*.canary.example.com`
- **prod**: `example.com` and `*.example.com`

## GitOps Integration

The GitOps workflow supports environment-specific deployments through ArgoCD applications that target specific namespaces.

## Deployment Process

1. Set the `ENVIRONMENT` environment variable
2. Apply the appropriate configuration for the target environment
3. Deploy using ArgoCD or kubectl

## Testing and Verification

To verify environment deployment:

1. Check that the correct namespace exists
2. Verify that environment-specific ConfigMaps are applied
3. Confirm that services are accessible at the correct domain
4. Validate that ingress rules are properly configured

## Best Practices

- Always use environment variables for domain configurations
- Implement proper namespace isolation between environments
- Use different storage configurations for different environments when needed
- Maintain separate secrets for each environment
- Implement appropriate resource limits for each environment
- Use environment-specific labels for easier management and monitoring
