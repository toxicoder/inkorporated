# Cloudflared Tunnel Service

This directory contains the Kubernetes manifests for deploying the Cloudflared tunnel service, which provides zero-trust access to services in the Inkorporated homelab infrastructure.

## Overview

Cloudflared is the self-hosted Cloudflare Tunnel client that enables secure, zero-trust access to services without exposing ports publicly. It integrates with Cloudflare Access for OIDC-based authentication and works alongside Traefik for ingress routing.

## Files

- `Namespace.yaml` - Creates the `cloudflared` namespace
- `Deployment.yaml` - Deploys the cloudflared tunnel service with 3 replicas and PodDisruptionBudget
- `ConfigMap.yaml` - Contains the tunnel configuration including ingress rules

## Configuration

The tunnel configuration in `ConfigMap.yaml` includes:
- Tunnel name: `ink-homelab`
- Credentials file path: `/etc/cred.json`
- Ingress rules for:
  - `*.overeazy.io` → Traefik service
  - `dashboard.overeazy.io` → Homepage service
- Warp routing disabled (for homelab use)

## Deployment

The deployment uses:
- Image: `cloudflare/cloudflared:latest`
- Command: `tunnel --config /etc/config.yaml`
- 3 replicas with PodDisruptionBudget (minAvailable: 2)
- ConfigMap for tunnel configuration
- Secret for credentials file

## Prerequisites

Before deploying this service:
1. Create a Cloudflare Tunnel in the Cloudflare dashboard
2. Generate a tunnel token and store it as a Kubernetes secret named `cloudflared-credentials` in the `cloudflared` namespace
3. Ensure Traefik and Authentik are deployed and functioning
4. Configure Cloudflare Access policies to allow access to services

## Security

- Uses sealed secrets for sensitive data (token)
- Runs with minimal required permissions
- Integrates with Authentik for centralized authentication
- Zero-trust access model with Cloudflare Tunnel
