# Inkorporated Services Implementation Status

This document tracks the implementation status of all services in the Inkorporated homelab infrastructure.

## Implemented Services

### Shared Services
- ✅ `cloudflared/` - Cloudflare Tunnel client for zero-trust access
- ✅ `homepage/` - User dashboard
- ✅ `traefik/` - Ingress controller
- ✅ `authentik/` - Identity provider
- ✅ `mongodb/` - NoSQL database
- ✅ `rocket.chat/` - Team chat
- ✅ `workadventure/` - Virtual office
- ✅ `jitsi/` - Video conferencing
- ✅ `coturn/` - TURN/STUN server
- ✅ `vaultwarden/` - Password manager
- ✅ `hashicorp-vault/` - Secrets management
- ✅ `ollama/` - Local LLM runner
- ✅ `open-webui/` - Ollama web interface

### Services To Be Implemented
- 🔄 `langflow/` - Visual LangChain builder
- 🔄 `kokoro/` - Local TTS server
- 🔄 `docling/` - Document parsing server
- 🔄 `appflowy/` - Collaborative knowledge base
- 🔄 `searxng/` - Metasearch engine
- 🔄 `surfsense/` - AI research agent
- 🔄 `perplexica/` - AI search engine
- 🔄 `linkwarden/` - Bookmark manager
- 🔄 `homebox/` - Inventory tracker
- 🔄 `homeassistant/` - Smart home hub
- 🔄 `kasm/` - Browser-based workspaces
- 🔄 `gitea/` - Git server
- 🔄 `coder/` - Cloud IDE workspaces
- 🔄 `cloudnativepg/` - PostgreSQL operator
- 🔄 `longhorn/` - Distributed block storage
- 🔄 `minio/` - S3 object storage
- 🔄 `velero/` - Backup/restore
- 🔄 `cert-manager/` - TLS automation
- 🔄 `metallb/` - LoadBalancer provider
- 🔄 `prometheus/` - Metrics collection
- 🔄 `grafana/` - Dashboards
- 🔄 `loki/` - Logging

## Implementation Priority

1. **Core Infrastructure** (Already started)
   - Traefik (complete)
   - Authentik (complete)
   - Homepage (complete)
   - MongoDB (complete)

2. **Application Services**
   - Rocket.Chat (complete)
   - WorkAdventure (complete)
   - Jitsi (complete)
   - Vaultwarden (complete)
   - HashiCorp Vault (complete)
   - Coturn (complete)
   - Ollama (complete)
   - Open WebUI (complete)

3. **AI Services**
   - Langflow
   - Kokoro TTS
   - Docling
   - SearXNG
   - Perplexica
   - SurfSense

4. **Productivity Services**
   - AppFlowy
   - LinkWarden
   - Homebox
   - Home Assistant
   - Kasm Workspaces

5. **Development Tools**
   - Gitea
   - Coder

6. **Infrastructure Services**
   - CloudNativePG
   - Longhorn
   - MinIO
   - Velero
   - Cert-manager
   - MetalLB
   - Prometheus/Grafana/Loki

## Implementation Approach

Each service follows a consistent pattern:
1. Create Namespace
2. Create Core Deployment with appropriate resources
3. Create Service
4. Create PodDisruptionBudget (where applicable)
5. Create ConfigMap (where applicable)
6. Create Ingress (where applicable)
7. Create Secrets (where applicable)

## Next Steps

Continue implementing services in the order of priority, starting with database services that other applications depend on.
