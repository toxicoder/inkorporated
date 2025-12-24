# Inkorporated Apps Directory

This directory contains GitOps manifests for all services in the Inkorporated homelab infrastructure.

## Structure

- `shared/` - Common services deployed to all environments
- `per-env/` - Environment-specific services (dev, staging, uat, canary, prod)
- `priv/` - Private/optional services (not deployed by default)
- `cluster-scoped/` - Cluster-level resources

## Services Implemented

### Shared Services (Currently Implemented)
- `cloudflared/` - Cloudflare Tunnel client for zero-trust access

### Shared Services (To Be Implemented)
- `pfSense/` - pfSense VM (implemented at infrastructure level)
- `homepage/` - User dashboard
- `traefik/` - Ingress controller
- `authentik/` - Identity provider
- `rocket.chat/` - Team chat
- `workadventure/` - Virtual office
- `jitsi/` - Video conferencing
- `coturn/` - TURN/STUN server
- `vaultwarden/` - Password manager
- `hashicorp-vault/` - Secrets management
- `ollama/` - Local LLM runner
- `open-webui/` - Ollama web interface
- `langflow/` - Visual LangChain builder
- `kokoro/` - Local TTS server
- `docling/` - Document parsing server
- `appflowy/` - Collaborative knowledge base
- `searxng/` - Metasearch engine
- `surfsense/` - AI research agent
- `perplexica/` - AI search engine
- `linkwarden/` - Bookmark manager
- `homebox/` - Inventory tracker
- `homeassistant/` - Smart home hub
- `kasm/` - Browser-based workspaces
- `gitea/` - Git server
- `coder/` - Cloud IDE workspaces
- `mongodb/` - NoSQL database
- `cloudnativepg/` - PostgreSQL operator
- `longhorn/` - Distributed block storage
- `minio/` - S3 object storage
- `velero/` - Backup/restore
- `cert-manager/` - TLS automation
- `metallb/` - LoadBalancer provider
- `prometheus/` - Metrics collection
- `grafana/` - Dashboards
- `loki/` - Logging

## Deployment Pattern

All services follow the same pattern:
1. Namespace definition
2. Core resources (Deployment, Service, ConfigMap, Secret)
3. PodDisruptionBudget (where applicable)
4. Ingress definitions (where applicable)

## Implementation Status

- ✅ `cloudflared/` - Complete
- 🔄 `homepage/` - In progress
- 🔄 `traefik/` - In progress
- 🔄 `authentik/` - In progress
- 🔄 `rocket.chat/` - In progress
- 🔄 `workadventure/` - In progress
- 🔄 `jitsi/` - In progress
- 🔄 `coturn/` - In progress
- 🔄 `vaultwarden/` - In progress
- 🔄 `hashicorp-vault/` - In progress
- 🔄 `ollama/` - In progress
- 🔄 `open-webui/` - In progress
- 🔄 `langflow/` - In progress
- 🔄 `kokoro/` - In progress
- 🔄 `docling/` - In progress
- 🔄 `appflowy/` - In progress
- 🔄 `searxng/` - In progress
- 🔄 `surfsense/` - In progress
- 🔄 `perplexica/` - In progress
- 🔄 `linkwarden/` - In progress
- 🔄 `homebox/` - In progress
- 🔄 `homeassistant/` - In progress
- 🔄 `kasm/` - In progress
- 🔄 `gitea/` - In progress
- 🔄 `coder/` - In progress
- 🔄 `mongodb/` - In progress
- 🔄 `cloudnativepg/` - In progress
- 🔄 `longhorn/` - In progress
- 🔄 `minio/` - In progress
- 🔄 `velero/` - In progress
- 🔄 `cert-manager/` - In progress
- 🔄 `metallb/` - In progress
- 🔄 `prometheus/` - In progress
- 🔄 `grafana/` - In progress
- 🔄 `loki/` - In progress

## Implementation Progress

This is a large-scale implementation project. Services are being implemented in phases, following the detailed task breakdown in the implementation plan.
