---
layout: doc
---

# Service-Specific Documentation

This document provides detailed documentation for each service in the Inkorporated homelab infrastructure, organized by service type and including technical specifications, configuration details, and integration information.

## Collaboration Services

### Rocket.Chat

**Description**: Team chat platform for real-time communication with channels, DMs, and video calls.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: MongoDB replica set
- **High Availability**: 3 replicas with PodDisruptionBudget
- **Networking**: Ingress with subdomain `chat.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rocketchat
  namespace: rocketchat
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rocketchat
  template:
    metadata:
      labels:
        app: rocketchat
    spec:
      containers:
      - name: rocketchat
        image: rocketchat/rocket.chat:latest
        ports:
        - containerPort: 3000
        env:
        - name: MONGO_URL
          value: "mongodb://mongodb:27017/rocketchat"
        - name: ROOT_URL
          value: "https://chat.example.com"
```

**Integration Points**:
- Jitsi Meet for video calls
- Authentik for SSO authentication
- MongoDB for data persistence

### WorkAdventure

**Description**: 2D virtual office environment with proximity-based video calling.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: PostgreSQL cluster
- **High Availability**: 3 backend replicas with PodDisruptionBudget
- **Networking**: Ingress with subdomain `work.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workadventure
  namespace: workadventure
spec:
  replicas: 3
  selector:
    matchLabels:
      app: workadventure
  template:
    metadata:
      labels:
        app: workadventure
    spec:
      containers:
      - name: workadventure
        image: workadventure/server:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          value: "postgresql://workadventure:password@postgres-ha-rw:5432/workadventure"
        - name: BASE_URL
          value: "https://work.example.com"
```

**Integration Points**:
- Jitsi Meet for video conferencing
- Authentik for SSO authentication
- PostgreSQL for data persistence

### Jitsi Meet

**Description**: Video conferencing solution with integrated chat and screen sharing.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: Config persistence
- **High Availability**: Multiple JVB replicas
- **Networking**: Ingress with subdomain `jitsi.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jitsi
  namespace: jitsi
spec:
  replicas: 3
  selector:
    matchLabels:
      app: jitsi
  template:
    metadata:
      labels:
        app: jitsi
    spec:
      containers:
      - name: jitsi
        image: jitsi/jitsi-meet:latest
        ports:
        - containerPort: 80
        - containerPort: 443
        - containerPort: 10000
        env:
        - name: PUBLIC_URL
          value: "https://jitsi.example.com"
```

**Integration Points**:
- Rocket.Chat for chat integration
- WorkAdventure for virtual office integration
- Coturn for NAT traversal

### Coturn

**Description**: TURN/STUN server for NAT traversal in video conferencing.

**Technical Details**:
- **Authentication**: Config-based authentication
- **Storage**: Config secret
- **High Availability**: Multiple replicas
- **Networking**: Dedicated ports for TURN/STUN

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coturn
  namespace: coturn
spec:
  replicas: 3
  selector:
    matchLabels:
      app: coturn
  template:
    metadata:
      labels:
        app: coturn
    spec:
      containers:
      - name: coturn
        image: coturn/coturn:latest
        ports:
        - containerPort: 3478
        - containerPort: 5349
        - containerPort: 10000
        args:
        - -c
        - 1000
        - -m
        - 10
```

## Productivity Services

### AppFlowy

**Description**: Collaborative knowledge base alternative to Notion.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: PostgreSQL cluster
- **High Availability**: 3 replicas with PodDisruptionBudget
- **Networking**: Ingress with subdomain `appflowy.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: appflowy
  namespace: appflowy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: appflowy
  template:
    metadata:
      labels:
        app: appflowy
    spec:
      containers:
      - name: appflowy
        image: appflowy/appflowy:latest
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          value: "postgresql://appflowy:password@postgres-ha-rw:5432/appflowy"
        - name: BASE_URL
          value: "https://appflowy.example.com"
```

**Integration Points**:
- Authentik for SSO authentication
- PostgreSQL for data persistence

### LinkWarden

**Description**: Bookmark manager for archiving and organizing links.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: PostgreSQL cluster
- **High Availability**: 3 replicas with PodDisruptionBudget
- **Networking**: Ingress with subdomain `links.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: linkwarden
  namespace: linkwarden
spec:
  replicas: 3
  selector:
    matchLabels:
      app: linkwarden
  template:
    metadata:
      labels:
        app: linkwarden
    spec:
      containers:
      - name: linkwarden
        image: linkwarden/linkwarden:latest
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          value: "postgresql://linkwarden:password@postgres-ha-rw:5432/linkwarden"
        - name: BASE_URL
          value: "https://links.example.com"
```

**Integration Points**:
- Authentik for SSO authentication
- PostgreSQL for data persistence

### Homebox

**Description**: Inventory tracker for managing assets and equipment.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: PostgreSQL cluster
- **High Availability**: Single replica
- **Networking**: Ingress with subdomain `homebox.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: homebox
  namespace: homebox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: homebox
  template:
    metadata:
      labels:
        app: homebox
    spec:
      containers:
      - name: homebox
        image: homebox/homebox:latest
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          value: "postgresql://homebox:password@postgres-ha-rw:5432/homebox"
        - name: BASE_URL
          value: "https://homebox.example.com"
```

**Integration Points**:
- Authentik for SSO authentication
- PostgreSQL for data persistence

### Home Assistant

**Description**: Smart home hub for automation and device control.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: Longhorn PVC
- **High Availability**: Single replica
- **Networking**: Ingress with subdomain `home.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: homeassistant
  namespace: homeassistant
spec:
  replicas: 1
  selector:
    matchLabels:
      app: homeassistant
  template:
    metadata:
      labels:
        app: homeassistant
    spec:
      containers:
      - name: homeassistant
        image: homeassistant/home-assistant:latest
        ports:
        - containerPort: 8123
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: homeassistant-pvc
```

**Integration Points**:
- Authentik for SSO authentication
- Longhorn for configuration persistence

## Remote Work Services

### Kasm Workspaces

**Description**: Browser-based workspaces for remote desktop access.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: PostgreSQL cluster and volumes
- **High Availability**: 3+ core replicas with PodDisruptionBudget
- **Networking**: Ingress with subdomain `kasm.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kasm
  namespace: kasm
spec:
  replicas: 3
  selector:
    matchLabels:
      app: kasm
  template:
    metadata:
      labels:
        app: kasm
    spec:
      containers:
      - name: kasm
        image: kasmweb/kasm:latest
        ports:
        - containerPort: 80
        - containerPort: 443
        env:
        - name: BASE_URL
          value: "https://kasm.example.com"
```

**Integration Points**:
- Authentik for SSO authentication
- PostgreSQL for user management
- Longhorn for persistent volumes

### Coder

**Description**: Cloud IDE workspaces for remote development.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: PostgreSQL cluster and PVCs
- **High Availability**: Conditional replicas
- **Networking**: Ingress with subdomain `coder.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coder
  namespace: coder
spec:
  replicas: 3
  selector:
    matchLabels:
      app: coder
  template:
    metadata:
      labels:
        app: coder
    spec:
      containers:
      - name: coder
        image: coder/coder:latest
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          value: "postgresql://coder:password@postgres-ha-rw:5432/coder"
        - name: BASE_URL
          value: "https://coder.example.com"
```

**Integration Points**:
- Authentik for SSO authentication
- PostgreSQL for data persistence
- Gitea for code repositories

## AI Services

### Ollama

**Description**: Local LLM runner for running large language models.

**Technical Details**:
- **Authentication**: None (local access only)
- **Storage**: Longhorn PVC for model cache
- **High Availability**: Single instance
- **Networking**: Internal service only

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: ollama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        volumeMounts:
        - name: models
          mountPath: /root/.ollama
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: ollama-pvc
```

**Integration Points**:
- Open WebUI for web interface
- Langflow for visual agent building
- Kokoro TTS for voice output
- Docling for document parsing

### Open WebUI

**Description**: Web interface for Ollama with RAG, TTS, and document parsing capabilities.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: PostgreSQL cluster
- **High Availability**: 3 replicas with PodDisruptionBudget
- **Networking**: Ingress with subdomain `webui.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: open-webui
  namespace: webui
spec:
  replicas: 3
  selector:
    matchLabels:
      app: open-webui
  template:
    metadata:
      labels:
        app: open-webui
    spec:
      containers:
      - name: open-webui
        image: ghcr.io/open-webui/open-webui:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          value: "postgresql://openwebui:password@postgres-ha-rw:5432/openwebui"
        - name: BASE_URL
          value: "https://webui.example.com"
        - name: OLLAMA_BASE_URL
          value: "http://ollama:11434"
```

**Integration Points**:
- Ollama for LLM backend
- Kokoro TTS for voice output
- Docling for document parsing
- Authentik for SSO authentication

### Langflow

**Description**: Visual LangChain builder for creating AI agents and pipelines.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: PostgreSQL cluster
- **High Availability**: 3 replicas with PodDisruptionBudget
- **Networking**: Ingress with subdomain `langflow.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: langflow
  namespace: langflow
spec:
  replicas: 3
  selector:
    matchLabels:
      app: langflow
  template:
    metadata:
      labels:
        app: langflow
    spec:
      containers:
      - name: langflow
        image: langflow/langflow:latest
        ports:
        - containerPort: 7860
        env:
        - name: DATABASE_URL
          value: "postgresql://langflow:password@postgres-ha-rw:5432/langflow"
        - name: BASE_URL
          value: "https://langflow.example.com"
```

**Integration Points**:
- Ollama for LLM backend
- Open WebUI for web interface
- Authentik for SSO authentication

### Kokoro TTS

**Description**: Local TTS server for voice output in AI applications.

**Technical Details**:
- **Authentication**: None (local access only)
- **Storage**: Model cache
- **High Availability**: Single replica
- **Networking**: Internal service only

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kokoro
  namespace: kokoro
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kokoro
  template:
    metadata:
      labels:
        app: kokoro
    spec:
      containers:
      - name: kokoro
        image: kokoro/kokoro:latest
        ports:
        - containerPort: 5000
```

**Integration Points**:
- Open WebUI for voice output
- Ollama for text generation
- Langflow for AI agent integration

### Docling

**Description**: Document parsing server for advanced RAG capabilities.

**Technical Details**:
- **Authentication**: None (local access only)
- **Storage**: Config files
- **High Availability**: Single replica
- **Networking**: Internal service only

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docling
  namespace: docling
spec:
  replicas: 1
  selector:
    matchLabels:
      app: docling
  template:
    metadata:
      labels:
        app: docling
    spec:
      containers:
      - name: docling
        image: docling/docling:latest
        ports:
        - containerPort: 8000
```

**Integration Points**:
- Open WebUI for document processing
- Langflow for AI agent integration
- Ollama for LLM backend

### SearXNG

**Description**: Metasearch engine for privacy-focused search.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: Config files
- **High Availability**: Single replica
- **Networking**: Ingress with subdomain `search.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: searxng
  namespace: searxng
spec:
  replicas: 1
  selector:
    matchLabels:
      app: searxng
  template:
    metadata:
      labels:
        app: searxng
    spec:
      containers:
      - name: searxng
        image: searxng/searxng:latest
        ports:
        - containerPort: 8080
        env:
        - name: BASE_URL
          value: "https://search.example.com"
```

**Integration Points**:
- Open WebUI for search integration
- Perplexica for AI search
- SurfSense for research agent

### SurfSense

**Description**: AI research agent for advanced knowledge work.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: PostgreSQL cluster and vector store
- **High Availability**: 3 replicas
- **Networking**: Ingress with subdomain `research.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: surfsense
  namespace: surfsense
spec:
  replicas: 3
  selector:
    matchLabels:
      app: surfsense
  template:
    metadata:
      labels:
        app: surfsense
    spec:
      containers:
      - name: surfsense
        image: surfsense/surfsense:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          value: "postgresql://surfsense:password@postgres-ha-rw:5432/surfsense"
        - name: BASE_URL
          value: "https://research.example.com"
```

**Integration Points**:
- SearXNG for search capabilities
- Open WebUI for interface
- Langflow for agent building

### Perplexica

**Description**: AI search engine for local Perplexity integration.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: Embeddings persistence
- **High Availability**: Single/3 replicas
- **Networking**: Ingress with subdomain `perplexica.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: perplexica
  namespace: perplexica
spec:
  replicas: 3
  selector:
    matchLabels:
      app: perplexica
  template:
    metadata:
      labels:
        app: perplexica
    spec:
      containers:
      - name: perplexica
        image: perplexica/perplexica:latest
        ports:
        - containerPort: 3000
        env:
        - name: BASE_URL
          value: "https://perplexica.example.com"
```

**Integration Points**:
- Open WebUI for search interface
- SearXNG for search capabilities
- SurfSense for research agent

## Security Services

### Vaultwarden

**Description**: Bitwarden-compatible password manager.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: PostgreSQL cluster
- **High Availability**: 3 replicas with PodDisruptionBudget
- **Networking**: Ingress with subdomain `vault.example.com`

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vaultwarden
  namespace: vaultwarden
spec:
  replicas: 3
  selector:
    matchLabels:
      app: vaultwarden
  template:
    metadata:
      labels:
        app: vaultwarden
    spec:
      containers:
      - name: vaultwarden
        image: vaultwarden/server:latest
        ports:
        - containerPort: 80
        - containerPort: 3012
        env:
        - name: DOMAIN
          value: "https://vault.example.com"
        - name: DATABASE_URL
          value: "postgresql://vaultwarden:password@postgres-ha-rw:5432/vaultwarden"
```

**Integration Points**:
- Authentik for SSO authentication
- PostgreSQL for data persistence

### HashiCorp Vault

**Description**: Secrets management solution.

**Technical Details**:
- **Authentication**: Integrated with Authentik SSO
- **Storage**: Integrated storage
- **High Availability**: 3 replicas with auto-unseal
- **Networking**: Internal service only

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault
  namespace: vault
spec:
  replicas: 3
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      containers:
      - name: vault
        image: hashicorp/vault:latest
        ports:
        - containerPort: 8200
        env:
        - name: VAULT_ADDR
          value: "http://vault:8200"
        - name: VAULT_API_ADDR
          value: "http://vault:8200"
```

**Integration Points**:
- Authentik for SSO authentication
- Applications using Vault for secrets

## Infrastructure Services

### CloudNativePG

**Description**: PostgreSQL operator and cluster for database management.

**Technical Details**:
- **Authentication**: None (internal access)
- **Storage**: Longhorn volumes
- **High Availability**: 3 instances
- **Networking**: Internal service only

**Configuration**:
```yaml
# Cluster configuration
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-ha
  namespace: cloudnativepg
spec:
  instances: 3
  storage:
    size: 50Gi
    storageClass: longhorn
  backup:
    retentionPolicy: 30d
    barmanObjectStore:
      destinationPath: s3://postgres-backups
      endpointURL: http://minio.minio.svc:9000
      serverName: postgres-ha
```

**Integration Points**:
- All services requiring PostgreSQL databases
- Backup to MinIO storage

### Longhorn

**Description**: Distributed block storage solution.

**Technical Details**:
- **Authentication**: None (internal access)
- **Storage**: Synology NFS optional
- **High Availability**: 3 replicas per volume
- **Networking**: Internal service only

**Configuration**:
```yaml
# Storage class configuration
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
provisioner: driver.longhorn.io
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880"
```

**Integration Points**:
- All services requiring persistent storage
- Backup to MinIO storage

### MinIO

**Description**: S3 object storage for backups and file storage.

**Technical Details**:
- **Authentication**: None (internal access)
- **Storage**: NFS PVC on Synology
- **High Availability**: Single instance
- **Networking**: Internal service only

**Configuration**:
```yaml
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: minio/minio:latest
        ports:
        - containerPort: 9000
        - containerPort: 9001
        args:
        - server
        - /data
        - --console-address
        - ":9001"
```

**Integration Points**:
- Velero for backups
- CloudNativePG for database backups
- Longhorn for recurring exports

### Velero

**Description**: Backup and restore solution for Kubernetes clusters.

**Technical Details**:
- **Authentication**: None (internal access)
- **Storage**: MinIO S3
- **High Availability**: Single instance
- **Networking**: Internal service only

**Configuration**:
```yaml
# Backup configuration
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 3 * * *"
  includedNamespaces:
  - "*"
  ttl: 720h
```

**Integration Points**:
- MinIO for backup storage
- All services requiring backup capability

### ArgoCD

**Description**: GitOps engine for declarative infrastructure management.

**Technical Details**:
- **Authentication**: None (internal access)
- **Storage**: N/A
- **High Availability**: Manual sync for infra
- **Networking**: Internal service only

**Configuration**:
```yaml
# Application configuration
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: inkorporated-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/toxicoder/inkorporated-k8s-apps.git
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: default
```

**Integration Points**:
- All infrastructure and application deployments
- Git repository for version control

### cert-manager

**Description**: TLS automation for Kubernetes.

**Technical Details**:
- **Authentication**: None (internal access)
- **Storage**: N/A
- **High Availability**: 3 replicas
- **Networking**: Internal service only

**Configuration**:
```yaml
# Certificate configuration
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
  namespace: default
spec:
  secretName: example-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "*.example.com"
```

**Integration Points**:
- Traefik for TLS termination
- All services requiring TLS certificates

### MetalLB

**Description**: LoadBalancer provider for Kubernetes.

**Technical Details**:
- **Authentication**: None (internal access)
- **Storage**: N/A
- **High Availability**: DaemonSet + controller
- **Networking**: Internal service only

**Configuration**:
```yaml
# ConfigMap configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: metallb-config
  namespace: metallb-system
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.240-192.168.1.250
```

**Integration Points**:
- Traefik for external service exposure
- All services requiring LoadBalancer

## Deployment and Management

### Infrastructure as Code

All infrastructure is managed through Infrastructure as Code principles using:
- **Terraform** for VM provisioning and initial setup
- **Ansible** for k3s cluster configuration
- **GitOps** through ArgoCD for application deployment
- **Kubernetes manifests** for declarative configuration

### Configuration Management

- **Secrets**: Kubernetes secrets with sealed secrets for Git-safe storage
- **Environment Variables**: Standard Kubernetes environment variable configuration
- **ConfigMaps**: For non-sensitive configuration data
- **Persistent Volumes**: Longhorn and NFS CSI for data persistence

### Monitoring and Logging

- **Prometheus**: Metrics collection from all services
- **Grafana**: Dashboards for system monitoring
- **Loki**: Unified logging across pods and hosts
- **Alertmanager**: Alerting for critical system events

### Security Practices

- **Zero-trust architecture**: Cloudflare Tunnel for external access
- **Centralized authentication**: Authentik for SSO
- **Network segmentation**: pfSense firewall and VLANs
- **Secrets management**: Vault and Vaultwarden for credentials
- **Regular updates**: Automated container image updates

## Service Integration Patterns

### Authentication Flow
1. User accesses any service via subdomain (e.g., `https://chat.example.com`)
2. Traefik forwards request to Authentik for authentication
3. Authentik validates credentials and issues JWT
4. User is redirected back to service with authenticated session
5. Service validates JWT and grants access

### Data Flow
1. Services communicate through internal Kubernetes networks
2. External services use Cloudflare Tunnel for secure access
3. All data is encrypted in-transit using TLS
4. Persistent data stored on Longhorn volumes or MinIO

### Backup Strategy
1. Daily backups scheduled via Velero
2. Database backups stored in MinIO
3. Application data backed up to MinIO
4. Regular restore testing performed

## Troubleshooting and Maintenance

### Common Issues
1. **Authentication failures**: Check Authentik configuration and service integration
2. **Storage issues**: Verify Longhorn and NFS CSI drivers are running
3. **Network connectivity**: Test Cloudflare Tunnel and Traefik ingress
4. **Service downtime**: Check pod status and logs

### Monitoring Commands
```bash
# Check pod status across all namespaces
kubectl get pods -A

# View logs for a specific service
kubectl logs -n <namespace> -l app=<service-name>

# Check service status
kubectl get svc -A

# Check ingress status
kubectl get ingress -A

# Check persistent volume claims
kubectl get pvc -A
```

### Maintenance Tasks
1. Regular security updates for container images
2. Monitoring and alerting review
3. Backup testing and verification
4. Performance optimization
5. Documentation updates

## Documentation Navigation
- [Project Overview](PROJECT_OVERVIEW.md) - Executive summary and key features
- [Complete Architecture](COMPREHENSIVE_PROJECT_DOCUMENTATION.md) - Full technical documentation
- [Implementation Status](IMPLEMENTATION_STATUS_TRACKING.md) - Current progress tracking
- [Discovery Summary](DISCOVERY_AND_DOCUMENTATION_SUMMARY.md) - Consolidated documentation overview
