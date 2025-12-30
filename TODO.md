# Project Implementation TODO List

This TODO list outlines a detailed implementation strategy for the Inkorporated homelab infrastructure project. The plan is organized into phases and follows SMART principles for each task. This document was created after thorough review of all project documentation including the technical design doc, memory bank files, and current progress tracking.

## Summary

- **Total Tasks**: 25  
- **Phases**:
  - Phase 1: Foundation & Preparation (Tasks 1-3)
  - Phase 2: Repository Setup (Task 4)
  - Phase 3: Infrastructure Bootstrap (Tasks 5-7)
  - Phase 4: Core Service Deployment (Tasks 8-20)
  - Phase 5: Post-Deployment Integration and Testing (Tasks 21-24)
  - Phase 6: Documentation & Finalization (Task 25)

## Phase 1: Foundation & Preparation

### Task 1.1: Validate Physical Infrastructure Readiness  

**Description**: Confirm physical server specs, network connectivity, power redundancy, and storage availability for Proxmox nodes.  
**Dependencies**: None  
**Effort**: 2 hours  
**Acceptance Criteria**: Documented validation report with hardware specifications and readiness checklist approved by team lead.  
**Risks**: Hardware incompatibility or insufficient resources may delay deployment.

### Task 1.2: Create Proxmox Cloud-Init Template for VMs  

**Description**: Build a standardized Cloud-Init template for all VMs (pfSense, k3s nodes) including OS configuration and network setup.  
**Dependencies**: Task 1.1 completed  
**Effort**: 4 hours  
**Acceptance Criteria**: Working Cloud-Init template tested with minimal VM deployment.  
**Risks**: Incorrect cloud-init parameters may cause boot failures.

### Task 1.3: Workstation Setup for Development Environment  

**Description**: Configure developer workstations with required tools (kubectl, terraform, ansible, git, VS Code devcontainer).  
**Dependencies**: None  
**Effort**: 2 hours  
**Acceptance Criteria**: All developers can run basic kubectl commands and Terraform plans against cluster.  
**Risks**: Missing dependencies or environment misconfiguration.

## Phase 2: Repository & Code Setup

### Task 2.1: Create Bootstrap Repository with Terraform/Ansible  

**Description**: Initialize git repo for infrastructure-as-code (Terraform + Ansible scripts).  
**Dependencies**: None  
**Effort**: 1 hour  
**Acceptance Criteria**: Private Gitea repository created with structure and initial commit.  
**Risks**: Incorrect repo configuration may lead to version control issues.

### Task 2.2: Create Apps Repository for GitOps Manifests  

**Description**: Set up separate apps repository (Gitea) for Kubernetes manifests under `apps/shared/`.  
**Dependencies**: Task 2.1 completed  
**Effort**: 1 hour  
**Acceptance Criteria**: Apps repo cloned, initial directory structure created.  
**Risks**: Repository permissions issues.

## Phase 3: Bootstrap Infrastructure

### Task 3.1: Provision VMs with Terraform (Proxmox)  

**Description**: Use Terraform to deploy required Proxmox VMs (pfSense, k3s control plane/workers).  
**Dependencies**: Tasks 1.1-1.2 completed  
**Effort**: 4 hours  
**Acceptance Criteria**: All VMs provisioned with correct specs and network configuration.  
**Risks**: Network misconfiguration may require manual fix.

### Task 3.2: Install k3s Cluster with Ansible  

**Description**: Run Ansible playbooks to install and configure k3s on provisioned VMs.  
**Dependencies**: Task 3.1 completed  
**Effort**: 4 hours  
**Acceptance Criteria**: k3s cluster up and running, nodes in Ready state.  
**Risks**: Network issues between nodes causing cluster failure.

### Task 3.3: Bootstrap ArgoCD for GitOps Deployment  

**Description**: Deploy ArgoCD into the k3s cluster to manage subsequent deployments via GitOps.  
**Dependencies**: Task 3.2 completed  
**Effort**: 3 hours  
**Acceptance Criteria**: ArgoCD UI accessible, synced with apps repository.  
**Risks**: Sync issues due to repo misconfiguration.

## Phase 4: Core Service Deployment

### Task 4.1: Deploy Longhorn Storage Cluster  

**Description**: Install and configure Longhorn for distributed block storage.  
**Dependencies**: Tasks 3.2-3.3 completed  
**Effort**: 3 hours  
**Acceptance Criteria**: Longhorn UI accessible, PVCs created successfully.  
**Risks**: Storage node failures requiring manual intervention.

### Task 4.2: Deploy NFS CSI Driver for Synology NAS Integration  

**Description**: Configure and deploy NFS CSI driver to integrate with existing Synology storage.  
**Dependencies**: Task 4.1 completed  
**Effort**: 3 hours  
**Acceptance Criteria**: PVCs mounted successfully from Synology share.  
**Risks**: Incorrect mount parameters causing access issues.

### Task 4.3: Deploy MinIO Object Storage for Backups  

**Description**: Set up MinIO as S3-compatible storage target for Velero backups.  
**Dependencies**: Tasks 4.1-4.2 completed  
**Effort**: 2 hours  
**Acceptance Criteria**: MinIO accessible via UI and CLI, configured with correct credentials.  
**Risks**: Misconfigured access keys preventing backup writes.

### Task 4.4: Deploy cert-manager for TLS Automation  

**Description**: Install cert-manager to handle Let's Encrypt certificate issuance.  
**Dependencies**: Tasks 3.2-3.3 completed  
**Effort**: 2 hours  
**Acceptance Criteria**: Certificate requests issued and validated successfully.  
**Risks**: DNS configuration issues causing validation failures.

### Task 4.5: Deploy MetalLB for LoadBalancer Provider  

**Description**: Install MetalLB to provide external IP assignments for services.  
**Dependencies**: Tasks 3.2-3.3 completed  
**Effort**: 2 hours  
**Acceptance Criteria**: Services with type LoadBalancer receive IPs and are accessible.  
**Risks**: Network policy misconfiguration blocking external access.

### Task 4.6: Deploy Traefik Ingress Controller  

**Description**: Install Traefik with forward-auth middleware for service routing.  
**Dependencies**: Tasks 4.4-4.5 completed  
**Effort**: 3 hours  
**Acceptance Criteria**: Services accessible via subdomains, TLS termination working.  
**Risks**: Incorrect ingress rules blocking services.

### Task 4.7: Deploy Authentik Identity Provider  

**Description**: Configure Authentik for SSO and OIDC with centralized authentication.  
**Dependencies**: Tasks 4.1-4.6 completed  
**Effort**: 4 hours  
**Acceptance Criteria**: Authentik login works, services protected by forward-auth.  
**Risks**: Misconfigured redirect URIs causing auth loops.

### Task 4.8: Deploy CloudNativePG for PostgreSQL  

**Description**: Set up CloudNativePG operator and primary database cluster.  
**Dependencies**: Tasks 4.1-4.2 completed  
**Effort**: 3 hours  
**Acceptance Criteria**: DB instances running, PVCs attached successfully.  
**Risks**: Storage volume issues causing DB failures.

### Task 4.9: Deploy MongoDB for Rocket.Chat  

**Description**: Configure standalone MongoDB instance for Rocket.Chat persistence.  
**Dependencies**: Tasks 4.1-4.2 completed  
**Effort**: 2 hours  
**Acceptance Criteria**: Rocket.Chat connects to MongoDB without errors.  
**Risks**: Incorrect connection strings causing app failures.

### Task 4.10: Deploy cloudflared Tunnel Service  

**Description**: Configure Cloudflare Tunnel with token integration for zero-trust access.  
**Dependencies**: Tasks 3.2-3.3 completed; Authentik setup (Task 4.7)
**Effort**: 3 hours  
**Acceptance Criteria**: Public services accessible via tunnel URLs, no direct port exposure.  
**Risks**: Incorrect cloudflared token causing service downtime.

## Phase 5: Post-Deployment Integration and Testing

### Task 5.1: Configure Authentik Applications and Groups  

**Description**: Set up OIDC clients for all apps (Rocket.Chat, WorkAdventure, etc.) and group mappings.  
**Dependencies**: Tasks 4.7 completed  
**Effort**: 3 hours  
**Acceptance Criteria**: Users can log in to all services with SSO.  
**Risks**: Incorrect client IDs causing authentication failures.

### Task 5.2: Deploy Observability Stack (Prometheus/Grafana/Loki)  

**Description**: Install monitoring stack and configure dashboards for all services.  
**Dependencies**: Tasks 4.1-4.6 completed  
**Effort**: 3 hours  
**Acceptance Criteria**: Grafana dashboards show metrics/logs from all components.  
**Risks**: Missing service exporters causing incomplete data.

### Task 5.3: Deploy Velero Backup Solution to MinIO  

**Description**: Configure Velero with S3 backend for scheduled cluster backups.  
**Dependencies**: Tasks 4.1-4.3 completed  
**Effort**: 2 hours  
**Acceptance Criteria**: Backups run successfully and can be restored from MinIO.  
**Risks**: Backup failures due to storage issues.

### Task 5.4: Configure pfSense Firewall Rules for Security Segmentation  

**Description**: Set up VLANs, firewall rules, and routing per network topology diagram.  
**Dependencies**: Tasks 3.1-3.2 completed (pfSense VM provisioned)  
**Effort**: 4 hours  
**Acceptance Criteria**: Network traffic follows planned segmentation, no unintended access.  
**Risks**: Firewall misconfigurations causing security gaps.

## Phase 6: Documentation & Finalization

### Task 6.1: Create Homepage Dashboard with App Shortcuts  

**Description**: Configure the Homepage app to provide user-friendly links to all services.  
**Dependencies**: All service deployments completed (Tasks 4-5)  
**Effort**: 2 hours  
**Acceptance Criteria**: User dashboard accessible, functional shortcuts to all apps.  
**Risks**: Incorrect URLs in configuration causing broken links.

### Task 6.2: Update README and Documentation with Deployment Instructions  

**Description**: Revise project documentation to reflect current deployment process and configurations.  
**Dependencies**: All services deployed successfully  
**Effort**: 3 hours  
**Acceptance Criteria**: Clear, step-by-step setup guide available for new developers.  
**Risks**: Outdated information causing deployment errors.

### Task 6.3: Perform End-to-End Testing of Critical Workflows  

**Description**: Validate user journeys (e.g., chat → video call → document sharing) across services.  
**Dependencies**: All services deployed and configured  
**Effort**: 4 hours  
**Acceptance Criteria**: All workflows functional; critical issues documented as bugs.  
**Risks**: Uncovered edge cases requiring code fixes.
