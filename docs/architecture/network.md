---
layout: doc
---

# Network Topology

The Inkorporated homelab implements a multi-zone network architecture to provide security segmentation and logical separation of services:

| Department/Zone | Subnet | Example Gateway IP | Purpose/Notes |
|-----------------|--------|-------------------|---------------|
| Headquarters | 10.0.1.0/24 | 10.0.1.1 | Executive offices and admin staff |
| Sales | 10.0.2.0/24 | 10.0.2.1 | Sales team workstations and CRM access |
| Engineering | 10.0.3.0/24 | 10.0.3.1 | Development and testing environments |
| Finance | 10.0.4.0/24 | 10.0.4.1 | Accounting and financial systems |
| Human Resources | 10.0.5.0/24 | 10.0.5.1 | HR personnel and sensitive data storage |
| IT | 10.0.6.0/24 | 10.0.6.1 | IT support and monitoring tools |
| Servers | 10.0.7.0/24 | 10.0.7.1 | Internal servers (e.g., file shares, databases) |
| DMZ | 10.0.8.0/24 | 10.0.8.1 | Public-facing services (e.g., web/email servers) |
| Guest WiFi | 10.0.9.0/24 | 10.0.9.1 | Visitor network - isolated with captive portal |
| Remote Access | 10.0.10.0/24 | 10.0.10.1 | VPN pool for remote workers |
| inkternal | 10.0.11.0/24 | 10.0.11.1 | Employee devices connect here |
| inklab | 10.0.12.0/24 | 10.0.12.1 | Internal-facing services |
| publink | 10.0.13.0/24 | 10.0.13.1 | Production services for external access |

## Architecture Overview

```mermaid
graph TD
    subgraph "Physical Layer"
        Proxmox["Proxmox Cluster\n4 Physical Nodes"]
        Synology["Synology NAS\nNFS Storage"]
    end

    subgraph "Virtualization Layer"
        pfSense["pfSense VM\nFirewall / Router / VPN"]
        k3sVMs["k3s VMs\n3 Control Planes + Workers"]
    end

    subgraph Kubernetes["Kubernetes Cluster (k3s)"]
        direction TB
        Namespaces["Namespaces\n- dev\n- staging\n- uat\n- canary\n- auto-push\n- priv\n- prod"]
        Shared["Shared Infrastructure\nTraefik | Authentik | Rocket.Chat | WorkAdventure\nJitsi | Coturn | Vaultwarden | HashiCorp Vault\nOllama | Open WebUI | Langflow | Kokoro TTS | Docling\nAppFlowy | SearXNG | SurfSense | Perplexica | LinkWarden\nHomebox | Home Assistant | Kasm Workspaces\nGitea | Coder | cert-manager | MetalLB\nLonghorn | CloudNativePG | MinIO | Velero | MongoDB | cloudflared"]
        Monitoring["Monitoring Stack\nPrometheus | Grafana | Alertmanager | Loki"]
        GitOps[ArgoCD]
    end

    subgraph "Observability & Backups"
        PromtailHosts["Promtail on Proxmox Hosts"]
        BackupsS3["MinIO S3 on NFS PVC"]
    end

    Internet --> pfSense
    pfSense --> k3sVMs
    pfSense --> Synology
    Proxmox --> pfSense
    Proxmox --> k3sVMs
    k3sVMs --> Kubernetes
    Kubernetes --> Namespaces
    Namespaces --> Shared & Monitoring & GitOps
    Synology --> NFS_CSI["NFS CSI Driver\n(Provides PVCs)"]
    NFS_CSI --> BackupsS3 & Monitoring
    Shared -->|Backups to| BackupsS3
    Proxmox --> PromtailHosts --> Loki[in Monitoring Stack]
    Kubernetes -->|Pod Logs via Promtail DS| Loki
    Shared -->|Metrics Scraped| Prometheus[in Monitoring Stack]
    CloudflareEdge[Cloudflare Edge] --> cloudflared[in Shared] --> SecureTunnel["Secure Tunnel\nZero-Trust Access to Services"]
```
