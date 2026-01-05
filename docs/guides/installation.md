---
layout: doc
---

# Implementation Phases

## Phase 1: Foundation & Preparation

**Task 1.01: Validate Physical Infrastructure Readiness**
- Verify Proxmox: 4 nodes online, ≥64GB RAM total, ≥16 CPU cores, ≥500GB storage
- Synology: Enable NFSv4.1, create `/volume1/k8s-backups`, permissions for LAN subnet
- Cloudflare: Create account, add domain overeasy.io, generate tunnel token

**Task 1.02: Create Proxmox Cloud-Init Template**
- Upload Ubuntu 24.04 ISO
- Create VM ID 9000: 2 CPU, 4GB RAM, 32GB disk, install minimal, enable qemu-guest-agent, SSH
- Convert to template

**Task 1.03: Workstation Setup**
- Install Terraform, Ansible, kubectl, helm, argocd CLI, kubeseal, cloudflared CLI
- Generate SSH key

## Phase 2: Repository & Code Setup

**Task 2.01: Create Bootstrap Repository**
- Create repo for Terraform/Ansible code
- Add terraform for VMs (3 CP, 2 workers), Synology folder
- Add Ansible for k3s

**Task 2.02: Create Apps Repository**
- Create repo for GitOps manifests
- Add dirs for shared (including cloudflared subdir with Deployment.yaml, ConfigMap for tunnel config.yaml, secret for token)

## Phase 3: Bootstrap Infrastructure

**Task 3.01: Provision VMs with Terraform**
- Fill tfvars (creds, template)
- `terraform apply`

**Task 3.02: Install k3s with Ansible**
- Update inventory
- Run playbook

**Task 3.03: Bootstrap ArgoCD**
- Create ns argocd
- Apply manifests
- Add repo, apply root app

## Phase 4: Core Infrastructure Deployment

**Task 4.01: Deploy NFS CSI Driver**
- Add Application: Helm chart, server=synology-ip, share=/volume1/k8s-backups

**Task 4.02: Deploy Longhorn Storage**
- Add Application: Chart v1.6.0, defaultReplicaCount=3, replicaSoftAntiAffinity=true

**Task 4.03: Deploy MinIO Object Storage**
- Add Application: Bitnami/minio, mode=standalone, storageClass=nfs-csi, size=5Ti, buckets=["longhorn-backups","velero-backups","cnpg-backups"]

**Task 4.04: Deploy CloudNativePG and MongoDB**
- CNPG operator v1.23.1, Cluster: instances=3, storage=longhorn 50Gi, backup to minio
- Mongo: Bitnami chart, replicaset=3, longhorn

**Task 4.05: Deploy Velero**
- Add Application: vmware-tanzu/velero, provider=aws, s3Url=http://minio.minio.svc:9000, bucket=velero-backups, credentials=sealed

**Task 4.06: Deploy cert-manager**
- Add Application: jetstack/cert-manager v1.14.0, installCRDs=true, replicas=3

**Task 4.07: Deploy MetalLB**
- Add Application: metallb/metallb v0.15.3, controller.replicas=1, speaker.daemonset=true

**Task 4.08: Deploy Traefik**
- Add Application: traefik/traefik v28.1.0, ports.websecure.tls=true

**Task 4.09: Deploy Authentik**
- Add Application: goauthentik/authentik, postgresql.host=postgres-ha-rw, database=authentik, secret=sealed

**Task 4.10: Deploy Vaultwarden**
- Add Application: vaultwarden/server, postgres.host=postgres-ha-rw, database=vaultwarden, secret=sealed

**Task 4.11: Deploy HashiCorp Vault**
- Add Application: hashicorp/vault v0.28.0, ha.replicas=3, raft.enabled=true, ui=true

**Task 4.12: Deploy cloudflared Tunnel**
- Create Cloudflare Tunnel in dashboard, get token=sealed
- Add Application: Deployment image=cloudflare/cloudflared:latest, command=["tunnel", "--config", "/etc/config.yaml"]

## Phase 5: Post-Deployment

**Task 5.01: Configure Authentik Providers and Groups**
- UI: OIDC providers for each service
- Groups: admins, developers, testers, priv-users, guests
- Bind apps to groups

**Task 5.02: Deploy User Dashboard (Homepage)**
- Add Application: homepage/homepage latest, namespace=homepage
- Config: services configuration with grouped shortcuts
- Forward-auth middleware
- Ingress: dashboard.example.com

**Task 5.03: Enable Backups and Test**
- Schedule: includeNamespaces=["*"], ttl=720h, schedule="0 3 * * *"
- Test backup/restore dev

**Task 5.04: Performance and Security Hardening**
- Quotas non-prod: cpu=4, mem=8Gi
- LimitRange default cpu=500m mem=512Mi
- Network policies deny default

**Task 5.05: Documentation Runbook**
- docs/ with URLs, creds, backups
- Add to Homepage
