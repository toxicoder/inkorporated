---
layout: doc
---

# NVIDIA DGX Spark Integration - Summary

## Overview
This document provides a comprehensive summary of the NVIDIA DGX Spark integration plan for the Inkorporated homelab infrastructure. The integration will add two NVIDIA DGX Spark systems as dedicated GPU-accelerated worker nodes to the existing k3s Kubernetes cluster.

## Current Project Status
Based on the analysis of all documentation, the Inkorporated project is currently in Phase 4 of its implementation lifecycle with the following status:

### Implemented Services
- ✅ Cloudflared (Zero-trust access)
- ✅ Homepage (User dashboard)
- ✅ Traefik (Ingress controller)
- ✅ Authentik (Identity provider)
- ✅ MongoDB (Database)
- ✅ Rocket.Chat (Team chat)
- ✅ WorkAdventure (Virtual office)
- ✅ Jitsi (Video conferencing)
- ✅ Coturn (TURN/STUN server)
- ✅ Vaultwarden (Password manager)
- ✅ HashiCorp Vault (Secrets management)
- ✅ Ollama (Local LLM runner)
- ✅ Open WebUI (Ollama web interface)

### Services To Be Implemented
- 🔄 Langflow (Visual LangChain builder)
- 🔄 Kokoro TTS (Local TTS server)
- 🔄 Docling (Document parsing server)
- 🔄 AppFlowy (Collaborative knowledge base)
- 🔄 SearXNG (Metasearch engine)
- 🔄 SurfSense (AI research agent)
- 🔄 Perplexica (AI search engine)
- 🔄 LinkWarden (Bookmark manager)
- 🔄 Homebox (Inventory tracker)
- 🔄 Home Assistant (Smart home hub)
- 🔄 Kasm Workspaces (Browser-based workspaces)
- 🔄 Gitea (Git server)
- 🔄 Coder (Cloud IDE workspaces)
- 🔄 CloudNativePG (PostgreSQL operator)
- 🔄 Longhorn (Distributed block storage)
- 🔄 MinIO (S3 object storage)
- 🔄 Velero (Backup/restore)
- 🔄 Cert-manager (TLS automation)
- 🔄 MetalLB (LoadBalancer provider)
- 🔄 Prometheus/Grafana/Loki (Monitoring)
- 🔄 DGX Spark Integration (GPU worker nodes)

## Integration Plan

### Phase 1: Prerequisite Infrastructure Deployment (Phase 4 Tasks)
Before integrating the DGX Spark systems, the following infrastructure components must be deployed:

1. **Task 4.01: Deploy NFS CSI Driver**
   - Purpose: Provide NFS-based persistent volumes for shared storage
   - Status: Not Started

2. **Task 4.02: Deploy Longhorn Storage** 
   - Purpose: Distributed block storage for GPU workloads
   - Status: Not Started

3. **Task 4.03: Deploy MinIO Object Storage**
   - Purpose: S3-compatible object storage for backups and AI datasets
   - Status: Not Started

4. **Task 4.04: Deploy cert-manager**
   - Purpose: TLS certificate automation for secure communication
   - Status: Not Started

5. **Task 4.05: Deploy MetalLB**
   - Purpose: LoadBalancer service type for external access
   - Status: Not Started

6. **Task 4.06: Deploy Observability Stack**
   - Purpose: Monitor GPU metrics and system performance
   - Status: Not Started

### Phase 2: DGX Spark Integration (Task 4.28)
Once prerequisite infrastructure is deployed, integrate the DGX Spark systems:

1. **Physical Setup**
   - Connect DGX systems to LAN switch via Ethernet
   - Configure static IPs in management VLAN
   - Connect DGX nodes directly with OSFP cables (400 Gbps total)
   - Configure private subnet for direct communication
   - Set up jumbo frames (MTU=9000) and bonding

2. **Software Installation**
   - Install k3s agent on DGX nodes
   - Label nodes for GPU scheduling: `node-role.kubernetes.io/ai-gpu=true`
   - Taint nodes for GPU workloads: `dedicated=gpu:NoSchedule`

3. **GPU Operator Deployment**
   - Deploy NVIDIA GPU Operator via Helm
   - Configure driver, device plugin, and DCGM components
   - Verify GPU functionality

### Phase 3: AI Workload Configuration
Update existing AI services to utilize GPU nodes:

1. **Ollama Deployment**
   - Apply node selector for GPU nodes
   - Configure GPU resource limits/requests

2. **Open WebUI Deployment**
   - Apply same node selector configuration
   - Configure GPU resources

3. **Langflow Deployment**
   - Configure node affinity and GPU resources

### Phase 4: Monitoring and Testing
1. **GPU Metrics Monitoring**
   - Configure DCGM exporter for GPU metrics
   - Set up Prometheus scraping
   - Create Grafana dashboards

2. **Performance Testing**
   - Deploy CUDA test workloads
   - Run distributed training jobs
   - Validate storage performance

## Implementation Timeline
- **Week 1**: Complete prerequisite infrastructure deployment (Longhorn, MetalLB, cert-manager, Observability)
- **Week 2**: Physical setup and k3s agent installation on DGX systems
- **Week 3**: GPU Operator deployment and AI service configuration
- **Week 4**: Testing and performance validation

## Resources Required
- **Hardware**: 2x NVIDIA DGX Spark systems (Grace CPU + Blackwell GPU)
- **Network**: 10/25/100 Gbps Ethernet connectivity, 400 Gbps direct OSFP links
- **Software**: k3s cluster (existing), NVIDIA GPU Operator Helm chart, Longhorn storage operator

## Success Criteria
- DGX nodes successfully join k3s cluster as worker nodes
- GPU Operator deployed and functional
- AI services can be scheduled on GPU nodes
- GPU metrics available through monitoring stack
- Performance benchmarks meet expected throughput requirements

## Documentation References
- Complete integration plan: `docs/DGX_INTEGRATION_PLAN.md`
- Implementation status tracking: `apps/shared/implementation_status.md`
- Progress tracking: `memory-bank/progress.md`

## Next Steps
1. Begin deployment of prerequisite infrastructure components
2. Prepare physical infrastructure for DGX systems
3. Update Ansible playbooks for DGX node configuration
4. Configure network settings per integration plan