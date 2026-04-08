# Service Deployment Guide

## Overview

This guide documents the standardized deployment patterns for Kubernetes services
in the Inkorporated platform.

## Standard Manifest Sequence

All services should follow this deployment order:

1. **Namespace.yaml** - Creates the isolated namespace
2. **ConfigMap.yaml** - Configuration data (optional)
3. **Secret.yaml** - Sensitive data (optional)
4. **Deployment.yaml** - Application pods
5. **Service.yaml** - Internal service discovery
6. **Ingress.yaml** - External access routing

## Example: Vaultwarden Deployment

```
vaultwarden/
├── Namespace.yaml
├── Secret.yaml
├── Deployment.yaml
├── Service.yaml
└── Ingress.yaml
```

## Multi-Component Services

For complex services like Authentik:

```
authentik/
├── Namespace.yaml
├── Deployment.yaml (main)
├── Deployment-server.yaml
├── Deployment-worker.yaml
├── Deployment-outpost.yaml
├── Service.yaml
├── Service-server.yaml
├── Service-worker.yaml
└── Ingress.yaml
```

## Validation

Ensure all manifests declare `namespace` field consistently.
