---
title: Security
description: Security for Inkorporated.
tags: [infrastructure]
---

# Security Implementation


**What's on this page**

- Documentation for this infrastructure topic.

**What this enables**


## Zero-trust access path

```mermaid
sequenceDiagram
  participant U as User
  participant CF as Cloudflare
  participant T as Tunnel
  participant TR as Traefik
  participant A as Authentik
  participant App as App
  U->>CF: HTTPS
  CF->>T: Authenticated edge
  T->>TR: Forward
  TR->>A: Forward auth
  A-->>TR: Allow
  TR->>App: Request
```

- Operators can deploy and operate Inkorporated systems confidently.

## Authentication & Authorization
- **Authentik**: Central identity provider with OIDC + 2FA enforcement
- **SSO Flow**: Login once → seamless across all services
- **Groups**: admins/full, developers limited AI models, etc.

## Network Security
- **pfSense**: Primary firewall (block all except necessary ports)
- **VPN Termination**: OpenVPN/WireGuard for remote access
- **IDS/IPS**: Via pfSense packages

## Data Protection
- **In-transit**: All encrypted via Traefik TLS
- **At-rest**: Longhorn storage encryption
- **Secrets**: Vault for apps; Vaultwarden for users; SealedSecrets in GitOps
