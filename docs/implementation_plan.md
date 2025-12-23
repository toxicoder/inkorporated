# Inkorporated Implementation Plan

## Overview
This document outlines the comprehensive implementation plan for the Inkorporated homelab infrastructure based on the technical design document. The plan follows the phased approach with clear milestones and deliverables.

## Phase 1: Foundation & Preparation

### Task 1.01: Validate Physical Infrastructure Readiness
**Objective**: Confirm hardware/network supports full stack including cloudflared tunnels
**Status**: Not Started
**Dependencies**: None
**Steps**:
1. Verify Proxmox: 4 nodes online, ≥64GB RAM total, ≥16 CPU cores, ≥500GB storage
2. Synology: Enable NFSv4.1, create `/volume1/k8s-backups`, permissions for LAN subnet
3. Cloudflare: Create account, add domain overeasy.io, generate tunnel token

### Task 1.02: Create Proxmox Cloud-Init Template
**Objective**: Template for k3s nodes
**Status**: Not Started
**Dependencies**: Task 1.01
**Steps**:
1. Upload Ubuntu 24.04 ISO
2. Create VM ID 9000: 2 CPU, 4GB RAM, 32GB disk, install minimal, enable qemu-guest-agent, SSH
3. Convert to template

### Task 1.03: Workstation Setup
**Objective**: Tools ready, including cloudflared CLI
**Status**: Not Started
**Dependencies**: None
**Steps**:
1. Install Terraform, Ansible, kubectl, helm, argocd CLI, kubeseal, cloudflared CLI
2. Generate SSH key

## Phase 2: Repository & Code Setup

### Task 2.01: Create Bootstrap Repository
**Objective**: Terraform/Ansible code
**Status**: Not Started
**Dependencies**: Task 1.03
**Steps**:
1. Create repo for Terraform/Ansible code
2. Add terraform for VMs (3 CP, 2 workers), Synology folder
3. Add Ansible for k3s

### Task 2.02: Create Apps Repository
**Objective**: GitOps manifests, including cloudflared
**Status**: Not Started
**Dependencies**: None
**Steps**:
1. Create repo for GitOps manifests
2. Add dirs for shared (including cloudflared subdir with Deployment.yaml, ConfigMap for tunnel config.yaml, secret for token)

## Phase 3: Bootstrap Infrastructure

### Task 3.01: Provision VMs with Terraform
**Objective**: Create nodes
**Status**: Not Started
**Dependencies**: Task 2.01
**Steps**:
1. Fill tfvars (creds, template)
2. `terraform apply`

### Task 3.02: Install k3s with Ansible
**Objective**: HA cluster
**Status**: Not Started
**Dependencies**: Task 3.01
**Steps**:
1. Update inventory
2. Run playbook

### Task 3.03: Bootstrap ArgoCD
**Objective**: GitOps
**Status**: Not Started
**Dependencies**: Task 3.02
**Steps**:
1. Create ns argocd
2. Apply manifests
3. Add repo, apply root app

## Phase 4: Core Infrastructure Deployment (Manual Sync Wave)

### Task 4.01: Deploy NFS CSI Driver
**Objective**: Synology PVCs
**Status**: Not Started
**Dependencies**: ArgoCD
**Steps**:
1. Add Application: Helm chart, server=synology-ip, share=/volume1/k8s-backups

### Task 4.02: Deploy Longhorn Storage
**Objective**: Block storage
**Status**: Not Started
**Dependencies**: Task 4.01
**Steps**:
1. Add Application: Chart v1.6.0, defaultReplicaCount=3, replicaSoftAntiAffinity=true

### Task 4.03: Deploy MinIO Object Storage
**Objective**: Backup target
**Status**: Not Started
**Dependencies**: Task 4.01
**Steps**:
1. Add Application: Bitnami/minio, mode=standalone, storageClass=nfs-csi, size=5Ti, buckets=["longhorn-backups","velero-backups","cnpg-backups"]

### Task 4.04: Deploy CloudNativePG and MongoDB
**Objective**: DBs
**Status**: Not Started
**Dependencies**: Longhorn
**Steps**:
1. CNPG operator v1.23.1, Cluster: instances=3, storage=longhorn 50Gi, backup to minio
2. Mongo: Bitnami chart, replicaset=3, longhorn

### Task 4.05: Deploy Velero
**Objective**: Backups
**Status**: Not Started
**Dependencies**: MinIO
**Steps**:
1. Add Application: vmware-tanzu/velero, provider=aws, s3Url=http://minio.minio.svc:9000, bucket=velero-backups, credentials=sealed

### Task 4.06: Deploy cert-manager
**Objective**: TLS
**Status**: Not Started
**Dependencies**: ArgoCD
**Steps**:
1. Add Application: jetstack/cert-manager v1.14.0, installCRDs=true, replicas=3

### Task 4.07: Deploy MetalLB
**Objective**: LB IPs
**Status**: Not Started
**Dependencies**: ArgoCD
**Steps**:
1. Add Application: metallb/metallb v0.15.3, controller.replicas=1, speaker.daemonset=true

### Task 4.08: Deploy Traefik
**Objective**: Ingress
**Status**: Not Started
**Dependencies**: cert-manager, MetalLB
**Steps**:
1. Add Application: traefik/traefik v28.1.0, ports.websecure.tls=true

### Task 4.09: Deploy Authentik
**Objective**: SSO
**Status**: Not Started
**Dependencies**: CNPG, Traefik
**Steps**:
1. Add Application: goauthentik/authentik, postgresql.host=postgres-ha-rw, database=authentik, secret=sealed

### Task 4.10: Deploy Vaultwarden
**Objective**: Passwords
**Status**: Not Started
**Dependencies**: CNPG, Authentik
**Steps**:
1. Add Application: vaultwarden/server, postgres.host=postgres-ha-rw, database=vaultwarden, secret=sealed

### Task 4.11: Deploy HashiCorp Vault
**Objective**: Secrets
**Status**: Not Started
**Dependencies**: Longhorn, Authentik
**Steps**:
1. Add Application: hashicorp/vault v0.28.0, ha.replicas=3, raft.enabled=true, ui=true

### Task 4.12: Deploy cloudflared Tunnel
**Objective**: Zero-trust access
**Status**: In Progress
**Dependencies**: Traefik, Authentik
**Steps**:
1. Create Cloudflare Tunnel in dashboard, get token=sealed
2. Add Application: Deployment image=cloudflare/cloudflared:latest, command=["tunnel", "--config", "/etc/config.yaml"]
3. Created deployment files in apps/shared/cloudflared/

## Phase 5: Post-Deployment

### Task 5.01: Configure Authentik Providers and Groups
**Objective**: SSO for all
**Status**: Not Started
**Dependencies**: All services
**Steps**:
1. UI: OIDC providers for each service
2. Groups: admins, developers, testers, priv-users, guests
3. Bind apps to groups

### Task 5.02: Deploy User Dashboard (Homepage)
**Objective**: User homepage with app shortcuts
**Status**: Not Started
**Dependencies**: Traefik, Authentik, all apps
**Steps**:
1. Add Application: homepage/homepage latest, namespace=homepage
2. Config: services configuration with grouped shortcuts
3. Forward-auth middleware
4. Ingress: dashboard.overeazy.io

### Task 5.03: Enable Backups and Test
**Objective**: DR
**Status**: Not Started
**Dependencies**: Velero
**Steps**:
1. Schedule: includeNamespaces=["*"], ttl=720h, schedule="0 3 * * *"
2. Test backup/restore dev

### Task 5.04: Performance and Security Hardening
**Objective**: Optimize/secure
**Status**: Not Started
**Dependencies**: All
**Steps**:
1. Quotas non-prod: cpu=4, mem=8Gi
2. LimitRange default cpu=500m mem=512Mi
3. Network policies deny default

### Task 5.05: Documentation Runbook
**Objective**: Ops guide
**Status**: Not Started
**Dependencies**: All
**Steps**:
1. docs/ with URLs, creds, backups
2. Add to Homepage

## Implementation Priority Order
1. Phase 1: Foundation & Preparation (Infrastructure validation)
2. Phase 2: Repository & Code Setup (Code organization)
3. Phase 3: Bootstrap Infrastructure (Core cluster setup)
4. Phase 4: Core Infrastructure Deployment (Services deployment)
5. Phase 5: Post-Deployment (Configuration and testing)

# task_progress
- [x] Analyze technical design document
- [x] Review current project structure
- [x] Initialize project documentation with proper context
- [x] Create comprehensive implementation plan
- [ ] Set up core infrastructure components
- [ ] Deploy cloudflared tunnel service
- [ ] Implement remaining services in phases
