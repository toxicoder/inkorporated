# Domain Templating Guide

## Overview

This guide explains the domain templating pattern used in Inkorporated's ArgoCD
deployments. Never hardcode domains in Ingress manifests.

## The Problem

Hardcoding domains like `example.com` in manifests causes:

- Multi-environment deployment failures
- Security issues with domain exposure
- Inability to test with different domains

## The Solution: ArgoCD Environment Substitution

### Template Pattern

Use the `{{ .Env.VAR_NAME }}` pattern for all domain references:

```yaml
spec:
  rules:
    - host: "{{ .Env.SERVICE_DOMAIN }}"
```

### Configuration Flow

1. Define variable in environment config:

1. Define variable in environment config:

   ```yaml
   # config/environments/dev/domain-config.yaml
   DOMAIN_BASE: dev.example.com
   ```

1. Reference in Ingress manifest:

   ```yaml
   host: "{{ .Env.DOMAIN_BASE }}"
   ```

## Validation

Run `./validate_domain_config.sh` to check for hardcoded domains.
