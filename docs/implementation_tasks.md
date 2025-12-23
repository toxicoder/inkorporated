# Inkorporated Implementation – Ultra-Detailed Atomic Engineering Task Breakdown (with cloudflared)

This breakdown is fully atomic and self-contained. Each task can be assigned independently, with explicit dependencies, required access, exact commands/configs, safe defaults, and verification steps. The design now includes **cloudflared** as a self-hosted Cloudflare Tunnel client for secure, zero-trust external access to services (complements pfSense), enabling encrypted tunnels without opening ports. cloudflared is deployed in `cloudflared` namespace, integrates with Traefik for ingress tunneling, and uses Cloudflare Access with Authentik for OIDC-based zero-trust policies.

**Total Phases**: 9  
**Key Additions**: cloudflared Deployment (cloudflare/cloudflared Docker image), tunnel config (ConfigMap with tunnel YAML), integration with Authentik for Access policies, optional multiple tunnels for envs. Headscale remains for mesh VPN.

## Phase 1: Foundation & Preparation

### Task 1.01: Validate Physical Infrastructure Readiness
**Objective**: Confirm hardware/network supports full stack including cloudflared tunnels.  
**Dependencies**: None  
**Access**: Proxmox UI, Synology DSM, Cloudflare account (for tunnel token)  
**Steps**:
1. Verify Proxmox: 4 nodes online, ≥64GB RAM total, ≥16 CPU cores, ≥500GB storage.
2. Synology: Enable NFSv4.1, create `/volume1/k8s-backups`, permissions for LAN subnet.
3. Cloudflare: Create account, add domain overeasy.io, generate tunnel token (via `cloudflared tunnel token` later).
**Safe Defaults**: NFS async = enabled, squash = none.
**Nice-to-Have**: Cloudflare DNS A record for *.overeazy.io to tunnel UUID.
**Verification**: Mount test; Cloudflare dashboard shows domain.
**Troubleshooting**: Tunnel token invalid → regenerate.

### Task 1.02: Create Proxmox Cloud-Init Template
**Objective**: Template for k3s nodes.  
**Dependencies**: Task 1.01  
**Steps**:
1. Upload Ubuntu 24.04 ISO.
2. Create VM ID 9000: 2 CPU, 4GB RAM, 32GB disk, install minimal, enable qemu-guest-agent, SSH.
3. Convert to template.
**Safe Defaults**: DHCP.
**Nice-to-Have**: Pre-install cloudflared binary for testing.
**Verification**: Clone and boot.
**Troubleshooting**: Check logs.

### Task 1.03: Workstation Setup
**Objective**: Tools ready, including cloudflared CLI.  
**Dependencies**: None  
**Steps**:
1. Install Terraform, Ansible, kubectl, helm, argocd CLI, kubeseal, cloudflared CLI (`wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && sudo dpkg -i cloudflared-linux-amd64.deb`).
2. Generate SSH key.
**Verification**: `cloudflared version`.

## Phase 2: Repository & Code Setup

### Task 2.01: Create Bootstrap Repository
**Objective**: Terraform/Ansible code.  
**Dependencies**: Task 1.03  
**Steps**:
1. Create repo.
2. Add terraform for VMs (3 CP, 2 workers), Synology folder.
3. Ansible for k3s.
**Safe Defaults**: VM 2CPU/4GB.
**Nice-to-Have**: Metrics args.
**Verification**: Plan shows resources.

### Task 2.02: Create Apps Repository
**Objective**: GitOps manifests, including cloudflared.  
**Dependencies**: None  
**Steps**:
1. Create repo.
2. Add dirs for shared (add cloudflared subdir with Deployment.yaml for cloudflare/cloudflared image, ConfigMap for tunnel config.yaml, secret for token).
**Safe Defaults**: cloudflared --url http://traefik.traefik.svc:80.
**Nice-to-Have**: Multiple tunnels for prod/priv.
**Verification**: Clones clean.

## Phase 3: Bootstrap Infrastructure

### Task 3.01: Provision VMs with Terraform
**Objective**: Create nodes.  
**Dependencies**: Task 2.01  
**Steps**:
1. Fill tfvars (creds, template).
2. `terraform apply`.
**Safe Defaults**: DHCP.
**Nice-to-Have**: Labels.
**Verification**: VMs running.

### Task 3.02: Install k3s with Ansible
**Objective**: HA cluster.  
**Dependencies**: Task 3.01  
**Steps**:
1. Update inventory.
2. Run playbook.
**Safe Defaults**: v1.30.4+k3s1, disable defaults.
**Nice-to-Have**: Flannel wireguard.
**Verification**: Get nodes.

### Task 3.03: Bootstrap ArgoCD
**Objective**: GitOps.  
**Dependencies**: Task 3.02  
**Steps**:
1. Create ns argocd.
2. Apply manifests.
3. Add repo, apply root app.
**Safe Defaults**: Manual.
**Nice-to-Have**: Image updater.
**Verification**: UI syncs.

## Phase 4: Core Infrastructure Deployment (Manual Sync Wave)

### Task 4.01: Deploy NFS CSI Driver
**Objective**: Synology PVCs.  
**Dependencies**: ArgoCD  
**Steps**:
1. Add Application: Helm chart, server=synology-ip, share=/volume1/k8s-backups.
**Safe Defaults**: reclaimPolicy=Retain, mountOptions=["nfsvers=4.1","async"].
**Nice-to-Have**: Read-only for backups.
**Verification**: Get storageclass.

### Task 4.02: Deploy Longhorn Storage
**Objective**: Block storage.  
**Dependencies**: Task 4.01  
**Steps**:
1. Add Application: Chart v1.6.0, defaultReplicaCount=3, replicaSoftAntiAffinity=true.
**Safe Defaults**: backupTarget="s3://longhorn-backups@http://minio.minio.svc:9000/".
**Nice-to-Have**: recurringSnapshotCron="0 */6 * * *".
**Verification**: UI.

### Task 4.03: Deploy MinIO Object Storage
**Objective**: Backup target.  
**Dependencies**: Task 4.01  
**Steps**:
1. Add Application: Bitnami/minio, mode=standalone, storageClass=nfs-csi, size=5Ti, buckets=["longhorn-backups","velero-backups","cnpg-backups"].
2. SealedSecret for root credentials.
**Safe Defaults**: cpu=500m, mem=1Gi.
**Nice-to-Have**: Ingress for console.
**Verification**: mc alias.

### Task 4.04: Deploy CloudNativePG and MongoDB
**Objective**: DBs.  
**Dependencies**: Longhorn  
**Steps**:
1. CNPG operator v1.23.1, Cluster: instances=3, storage=longhorn 50Gi, backup to minio.
2. Mongo: Bitnami chart, replicaset=3, longhorn.
**Safe Defaults**: max_connections=400.
**Nice-to-Have**: Monitoring enabled.
**Verification**: Connect test.

### Task 4.05: Deploy Velero
**Objective**: Backups.  
**Dependencies**: MinIO  
**Steps**:
1. Add Application: vmware-tanzu/velero, provider=aws, s3Url=http://minio.minio.svc:9000, bucket=velero-backups, credentials=sealed.
2. Schedule CR: includedNamespaces=["*"], ttl=720h, schedule="0 3 * * *".
**Safe Defaults**: snapshotsEnabled=true.
**Nice-to-Have**: cleanUpCRDs=true.
**Verification**: Backup test.

### Task 4.06: Deploy cert-manager
**Objective**: TLS.  
**Dependencies**: ArgoCD  
**Steps**:
1. Add Application: jetstack/cert-manager v1.14.0, installCRDs=true, replicas=3.
2. ClusterIssuer letsencrypt-staging: acme.server=https://acme-staging-v02.api.letsencrypt.org/directory, email=admin@overeazy.io, solvers.http01.ingress.class=traefik.
**Safe Defaults**: solvers.http01.enabled=true.
**Nice-to-Have**: Affinity weight=100.
**Verification**: Get clusterissuer Ready.

### Task 4.07: Deploy MetalLB
**Objective**: LB IPs.  
**Dependencies**: ArgoCD  
**Steps**:
1. Add Application: metallb/metallb v0.15.3, controller.replicas=1, speaker.daemonset=true.
2. IPAddressPool: addresses=["192.168.1.100-192.168.1.150"].
3. L2Advertisement.
**Safe Defaults**: No BGP.
**Nice-to-Have**: Speaker affinity workers.
**Verification**: Test LB service gets IP.

### Task 4.08: Deploy Traefik
**Objective**: Ingress.  
**Dependencies**: cert-manager, MetalLB  
**Steps**:
1. Add Application: traefik/traefik v28.1.0, ports.websecure.tls=true, additionalArguments=["--entrypoints.websecure.forwardauth.address=http://authentik-outpost.authentik.svc:9000/api/outpost.goauthentik.io/auth/traefik"].
2. replicas=3, PDB enabled.
**Safe Defaults**: KubernetesCRD enabled.
**Nice-to-Have**: Persistence ACME 1Gi.
**Verification**: Test ingress.

### Task 4.09: Deploy Authentik
**Objective**: SSO.  
**Dependencies**: CNPG, Traefik  
**Steps**:
1. Add Application: goauthentik/authentik, postgresql.host=postgres-ha-rw, database=authentik, secret=sealed, server.replicas=3, worker.replicas=1, outpost.replicas=1.
2. Bootstrap password sealed, change immediately.
3. UI: Create providers/groups.
**Safe Defaults**: default_policy=deny.
**Nice-to-Have**: Redis caching.
**Verification**: Login.

### Task 4.10: Deploy Vaultwarden
**Objective**: Passwords.  
**Dependencies**: CNPG, Authentik  
**Steps**:
1. Add Application: vaultwarden/server, postgres.host=postgres-ha-rw, database=vaultwarden, secret=sealed, replicas=3, PDB=true.
2. OIDC issuer=https://authentik.overeazy.io/application/o/vaultwarden/.
**Safe Defaults**: admin_token=changeme (disable after).
**Nice-to-Have**: Emergency access=true.
**Verification**: Login.

### Task 4.11: Deploy HashiCorp Vault
**Objective**: Secrets.  
**Dependencies**: Longhorn, Authentik  
**Steps**:
1. Add Application: hashicorp/vault v0.28.0, ha.replicas=3, raft.enabled=true, ui=true.
2. Post-sync: auth enable oidc, configure with Authentik.
**Safe Defaults**: Resources cpu=500m mem=1Gi.
**Nice-to-Have**: Auto-unseal k8s.
**Verification**: kv put/get.

### Task 4.12: Deploy cloudflared Tunnel
**Objective**: Zero-trust access.  
**Dependencies**: Traefik, Authentik (for Cloudflare Access)  
**Steps**:
1. Create Cloudflare Tunnel in dashboard, get token=sealed.
2. Add Application: Deployment image=cloudflare/cloudflared:latest, command=["tunnel", "--config", "/etc/config.yaml"], ConfigMap config.yaml: tunnel: ink-homelab, credentials-file: /etc/cred.json (sealed token), ingress=[{hostname="*.overeazy.io", service="http://traefik.traefik.svc:80"}], replicas=3, PDB=true.
3. In Cloudflare Access: Add application for overeasy.io, policy with Authentik OIDC group check (e.g., allow admins).
**Safe Defaults**: warp-routing.enabled=false (homelab only).
**Nice-to-Have**: Multiple tunnels for envs (e.g., dev.overeazy.io separate).
**Verification**: `cloudflared tunnel list`; access subdomain externally → Authentik then service.
**Troubleshooting**: Tunnel down → check token, Cloudflare logs.

### Task 4.13: Deploy Ollama
**Objective**: LLM.  
**Dependencies**: Longhorn  
**Steps**:
1. Deployment: ollama/ollama, PVC longhorn 100Gi, initJob pull llama3.2:3b.
**Safe Defaults**: Concurrent=1.
**Nice-to-Have**: GPU.
**Verification**: Test generate.

### Task 4.14: Deploy Kokoro TTS and Docling
**Objective**: Open WebUI enhancements.  
**Dependencies**: Longhorn  
**Steps**:
1. Kokoro: kokoroio/kokoro, port=8080.
2. Docling: docling/docling-serve, port=80.
**Safe Defaults**: Voice=english.
**Nice-to-Have**: Redis cache.
**Verification**: Test endpoints.

### Task 4.15: Deploy Open WebUI
**Objective**: AI chat.  
**Dependencies**: Ollama, Kokoro, Docling, Authentik, CNPG  
**Steps**:
1. Helm openwebui/open-webui, postgres=postgres-ha-rw, ollama_base=http://ollama:11434, openai_base=http://kokoro:8080/v1, document_parser=http://docling:80, oidc=true, issuer=https://authentik/application/o/openwebui/, replicas=3.
**Safe Defaults**: rag=true.
**Nice-to-Have**: cache_ttl=3600s.
**Verification**: Response with doc/voice.

### Task 4.16: Deploy Langflow
**Objective**: AI builder.  
**Dependencies**: Ollama, CNPG, Authentik  
**Steps**:
1. Deployment langflow-ai/langflow, postgres=postgres-ha-rw, backend=ollama, oidc=true, replicas=3.
**Safe Defaults**: Port=7860.
**Nice-to-Have**: Custom components.
**Verification**: Test flow.

### Task 4.17: Deploy Coturn
**Objective**: NAT video.  
**Dependencies**: Traefik  
**Steps**:
1. Deployment coturn/coturn, realm=overeazy.io, auth-secret=sealed, replicas=2.
**Safe Defaults**: listening-port=3478.
**Nice-to-Have**: Relay threads=4.
**Verification**: uclient test.

### Task 4.18: Deploy Jitsi Meet
**Objective**: Video.  
**Dependencies**: Coturn  
**Steps**:
1. Helm jitsi/jitsi-meet, jvb.replicas=2, turn.uris=stun:coturn:3478.
**Safe Defaults**: publicURL=https://jitsi.overeazy.io.
**Nice-to-Have**: Jibri recording.
**Verification**: Room join.

### Task 4.19: Deploy Rocket.Chat
**Objective**: Chat.  
**Dependencies**: MongoDB, Jitsi, Coturn, Authentik  
**Steps**:
1. Helm deliveryhero/rocket.chat, mongo.uri=mongodb://..., jitsi.url=https://jitsi, oidc=true, replicas=3.
**Safe Defaults**: push=false.
**Nice-to-Have**: Alert bots.
**Verification**: Channel call.

### Task 4.20: Deploy WorkAdventure
**Objective**: Virtual office.  
**Dependencies**: Jitsi, Coturn, CNPG, Authentik  
**Steps**:
1. Manifests, postgres=postgres-ha-rw, jitsiUrl=https://jitsi, turnUrl=turn:coturn:3478, oidc=true, backend replicas=3.
**Safe Defaults**: Default map.
**Nice-to-Have**: Custom map PVC.
**Verification**: Proximity chat.

### Task 4.21: Deploy AppFlowy
**Objective**: Knowledge.  
**Dependencies**: CNPG, Authentik  
**Steps**:
1. Helm appflowyinc/appflowy-cloud, postgres=postgres-ha-rw, oidc=true, replicas=3.
**Safe Defaults**: storage=10Gi.
**Nice-to-Have**: Real-time collab.
**Verification**: Doc create.

### Task 4.22: Deploy SearXNG
**Objective**: Search.  
**Dependencies**: Traefik  
**Steps**:
1. Deployment searxng/searxng, engines=google bing, rate_limit=true.
**Safe Defaults**: instance_name=Inkorporated.
**Nice-to-Have**: Redis cache.
**Verification**: Query.

### Task 4.23: Deploy SurfSense and Perplexica
**Objective**: AI research.  
**Dependencies**: Ollama, SearXNG  
**Steps**:
1. SurfSense: Manifests, backend=ollama, search=searxng, postgres=postgres-ha-rw, replicas=3.
2. Perplexica: Deployment, ollama_url, searxng_url.
**Safe Defaults**: min_score=0.5.
**Nice-to-Have**: Embeddings cache.
**Verification**: Test query.

### Task 4.24: Deploy LinkWarden, Homebox, Home Assistant
**Objective**: Utilities.  
**Dependencies**: CNPG, Authentik  
**Steps**:
1. LinkWarden: Deployment, postgres=postgres-ha-rw, oidc=true, replicas=3.
2. Homebox: Deployment, postgres=postgres-ha-rw.
3. Home Assistant: Core, persistence=longhorn 50Gi.
**Safe Defaults**: HA no add-ons.
**Nice-to-Have**: HA MQTT.
**Verification**: Add test.

### Task 4.25: Deploy Kasm Workspaces
**Objective**: Browser apps.  
**Dependencies**: CNPG, Authentik  
**Steps**:
1. Helm kasmtech/kasm, postgres=postgres-ha-rw, workspaces=ubuntu firefox, replicas=3.
**Safe Defaults**: session_limit=5.
**Nice-to-Have**: GPU.
**Verification**: Launch.

### Task 4.26: Deploy Per-Env Gitea and Coder
**Objective**: Dev tools.  
**Dependencies**: CNPG, Authentik  
**Steps**:
1. ApplicationSet: envs dev-prod, gitea v10.0.0, coder latest, postgres, oidc, replicas=1 non-prod 3 prod.
**Safe Defaults**: Gitea admin=changeme.
**Nice-to-Have**: Gitea mirrors.
**Verification**: Repo in dev.

### Task 4.27: Deploy Observability Stack
**Objective**: Monitoring.  
**Dependencies**: All  
**Steps**:
1. kube-prometheus-stack v65.0.0, prometheus.storage=longhorn 50Gi.
2. Loki promtail, storage=nfs 100Gi.
3. Import dashboards.
**Safe Defaults**: Retention 30d.
**Nice-to-Have**: Slack alerts.
**Verification**: Grafana metrics.

## Phase 5: Post-Deployment

### Task 5.01: Configure Authentik Providers and Groups
**Objective**: SSO for all.  
**Dependencies**: All services  
**Steps**:
1. UI: OIDC providers for each (e.g., Rocket.Chat scopes=openid profile email).
2. Groups: admins, developers, testers, priv-users, guests.
3. Bind apps to groups.
**Safe Defaults**: deny default.
**Nice-to-Have**: Self-service.
**Verification**: SSO test 3 services.

### Task 5.02: Deploy User Dashboard (Homepage)
**Objective**: User homepage with app shortcuts.  
**Dependencies**: Traefik, Authentik, all apps  
**Steps**:
1. Add Application: homepage/homepage latest, namespace=homepage.
2. Config: services=[{group="Collaboration", items=[{name="Rocket.Chat", href="https://chat.overeazy.io", icon="rocketchat.png"}]}, {group="AI", items=[{name="Open WebUI", href="https://webui.overeazy.io", icon="ai.png"}]} ], layout=columns, theme=dark, showSearch=true.
3. Forward-auth middleware.
4. Ingress: dashboard.overeazy.io.
**Safe Defaults**: background=simple, color=slate.
**Nice-to-Have**: Kubernetes status, custom icons PVC, Authentik group-based widgets.
**Verification**: Login, click shortcut → SSO to app.

### Task 5.03: Enable Backups and Test
**Objective**: DR.  
**Dependencies**: Velero  
**Steps**:
1. Schedule: includeNamespaces=["*"], ttl=720h, schedule="0 3 * * *".
2. Test backup/restore dev.
**Safe Defaults**: snapshots=true.
**Nice-to-Have**: Exclude logs PVC.
**Verification**: Restore ok.

### Task 5.04: Performance and Security Hardening
**Objective**: Optimize/secure.  
**Dependencies**: All  
**Steps**:
1. Quotas non-prod: cpu=4, mem=8Gi.
2. LimitRange default cpu=500m mem=512Mi.
3. Network policies deny default.
**Safe Defaults**: Affinity weight=100.
**Nice-to-Have**: HPA Traefik.
**Verification**: Top stable.

### Task 5.05: Documentation Runbook
**Objective**: Ops guide.  
**Dependencies**: All  
**Steps**:
1. docs/ with URLs, creds, backups.
2. Add to Homepage.
**Verification**: Review.

This breakdown ensures connected, optimized system with Homepage as user entry. Assign sequentially.