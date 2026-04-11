---
layout: doc
---

# Implementation Plan: Inkorporated Production-Ready Infrastructure

## Overview

This document provides a comprehensive implementation plan for completing the Inkorporated hybrid cloud infrastructure at production level quality. The plan covers **22+ services** across **6 phases**, including complete AWS/GCP provider implementations, dual storage strategy, CloudNativePG database, Sealed Secrets for Git-safe secrets, and hybrid networking with both Tailscale and WireGuard.

### Scope and Context

The Inkorporated project is a hybrid cloud infrastructure-as-code solution combining:

- **On-premises**: Proxmox cluster with k3s Kubernetes
- **Cloud**: AWS/GCP burst capacity
- **GitOps**: ArgoCD for declarative deployment
- **Zero-trust**: Cloudflare Tunnel for external access

### High-Level Approach

1. **Foundation First**: Deploy storage, networking, and database before applications
2. **Wave-Based Deployment**: Logical groupings that minimize dependencies
3. **Environment-Per-Environment Keys**: Each environment has its own Sealed Secrets key
4. **Dual Storage Strategy**: Longhorn as primary, NFS CSI for large files
5. **Hybrid Networking**: Both Tailscale (ease) and WireGuard (control)

---

## Types

### Kubernetes Resource Types

#### Storage Classes

```yaml
# Primary: Longhorn
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
provisioner: driver.longhorn.io
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete

# Secondary: NFS
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs
provisioner: nfs.csi.k8s.io
allowVolumeExpansion: true
volumeBindingMode: Immediate
reclaimPolicy: Retain
```

#### CloudNativePG Cluster

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-ha
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:16.2
  storage:
    size: 50Gi
    storageClass: longhorn
  replication:
    synchronous: true
    replicationQuorum: true
```

#### Sealed Secrets Key Structure

```yaml
# Per-environment key generation
# dev: sealed-secrets-key-dev.yaml
# staging: sealed-secrets-key-staging.yaml
# prod: sealed-secrets-key-prod.yaml
```

### Terraform Resource Types

#### AWS VPC Structure

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.aws_vpc_cidr
  tags = {
    Name = "inkorporated-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.aws_public_subnet_cidr
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.aws_private_subnet_cidr
}
```

#### GCP VPC Structure

```hcl
resource "google_compute_network" "main" {
  name                    = "inkorporated-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "inkorporated-subnet"
  region        = var.gcp_region
  network       = google_compute_network.main.name
  ip_cidr_range = var.gcp_subnet_cidr
}
```

---

## Files

### New Files to Be Created

#### Phase 1: Core Infrastructure

**Longhorn Storage**
| File | Purpose |
|------|---------|
| `apps/shared/longhorn/Namespace.yaml` | Longhorn namespace |
| `apps/shared/longhorn/CRDs.yaml` | Custom resource definitions |
| `apps/shared/longhorn/Deployment.yaml` | Longhorn controller deployment |
| `apps/shared/longhorn/Service.yaml` | Longhorn services |
| `apps/shared/longhorn/StorageClass.yaml` | Longhorn storage class |

**NFS CSI Driver**
| File | Purpose |
|------|---------|
| `apps/shared/nfs-csi/Namespace.yaml` | NFS CSI namespace |
| `apps/shared/nfs-csi/Deployment.yaml` | NFS CSI driver deployment |
| `apps/shared/nfs-csi/StorageClass.yaml` | NFS storage class |

**MinIO Object Storage**
| File | Purpose |
|------|---------|
| `apps/shared/minio/Namespace.yaml` | MinIO namespace |
| `apps/shared/minio/Deployment.yaml` | MinIO server deployment |
| `apps/shared/minio/Service.yaml` | MinIO service |
| `apps/shared/minio/PVC.yaml` | Persistent volume claim |
| `apps/shared/minio/Secret.yaml` | MinIO credentials |

**MetalLB LoadBalancer**
| File | Purpose |
|------|---------|
| `apps/shared/metallb/Namespace.yaml` | MetalLB namespace |
| `apps/shared/metallb/Deployment.yaml` | MetalLB controller deployment |
| `apps/shared/metallb/ConfigMap.yaml` | IP address pool configuration |

**cert-manager**
| File | Purpose |
|------|---------|
| `apps/shared/cert-manager/Namespace.yaml` | cert-manager namespace |
| `apps/shared/cert-manager/Deployment.yaml` | cert-manager deployment |
| `apps/shared/cert-manager/Issuer.yaml` | Self-signed root issuer |
| `apps/shared/cert-manager/Certificate.yaml` | Root CA certificate |

**CloudNativePG**
| File | Purpose |
|------|---------|
| `apps/shared/cloudnativepg/CRDs.yaml` | CNPG custom resource definitions |
| `apps/shared/cloudnativepg/Operator.yaml` | CNPG operator deployment |
| `apps/shared/cloudnativepg/Cluster.yaml` | PostgreSQL cluster definition |
| `apps/shared/cloudnativepg/Secret.yaml` | PostgreSQL credentials |

**Sealed Secrets**
| File | Purpose |
|------|---------|
| `apps/shared/sealed-secrets/Namespace.yaml` | Sealed Secrets namespace |
| `apps/shared/sealed-secrets/Deployment.yaml` | Sealed Secrets controller |
| `config/environments/dev/sealed-secrets-key.yaml` | Dev environment key |
| `config/environments/staging/sealed-secrets-key.yaml` | Staging environment key |
| `config/environments/prod/sealed-secrets-key.yaml` | Prod environment key |

**External Secrets Operator**
| File | Purpose |
|------|---------|
| `apps/shared/external-secrets/Namespace.yaml` | External Secrets namespace |
| `apps/shared/external-secrets/Deployment.yaml` | External Secrets operator |
| `apps/shared/external-secrets/VaultProvider.yaml` | HashiCorp Vault provider config |

**Velero Backups**
| File | Purpose |
|------|---------|
| `apps/shared/velero/Namespace.yaml` | Velero namespace |
| `apps/shared/velero/Deployment.yaml` | Velero deployment |
| `apps/shared/velero/BackupStorageLocation.yaml` | MinIO backup location |
| `apps/shared/velero/VolumeSnapshotLocation.yaml` | Volume snapshot location |
| `apps/shared/velero/Schedule.yaml` | Backup schedules |

#### Phase 2: Observability

**Prometheus**
| File | Purpose |
|------|---------|
| `apps/shared/prometheus/Namespace.yaml` | Prometheus namespace |
| `apps/shared/prometheus/Deployment.yaml` | Prometheus server deployment |
| `apps/shared/prometheus/Service.yaml` | Prometheus service |
| `apps/shared/prometheus/ServiceMonitor.yaml` | Service monitor for self |
| `apps/shared/prometheus/Rules.yaml` | Alerting rules |

**Grafana**
| File | Purpose |
|------|---------|
| `apps/shared/grafana/Namespace.yaml` | Grafana namespace |
| `apps/shared/grafana/Deployment.yaml` | Grafana deployment |
| `apps/shared/grafana/Service.yaml` | Grafana service |
| `apps/shared/grafana/Ingress.yaml` | Grafana ingress |
| `apps/shared/grafana/ConfigMap.yaml` | Grafana configuration |
| `apps/shared/grafana/Dashboards/` | Pre-configured dashboards |

**Loki + Promtail**
| File | Purpose |
|------|---------|
| `apps/shared/loki/Namespace.yaml` | Loki namespace |
| `apps/shared/loki/Deployment.yaml` | Loki deployment |
| `apps/shared/loki/Service.yaml` | Loki service |
| `apps/shared/promtail/Namespace.yaml` | Promtail namespace |
| `apps/shared/promtail/Deployment.yaml` | Promtail deployment |
| `apps/shared/promtail/ConfigMap.yaml` | Promtail configuration |

#### Phase 3: Development Platform

**Gitea**
| File | Purpose |
|------|---------|
| `apps/shared/gitea/Deployment.yaml` | Gitea deployment |
| `apps/shared/gitea/Service.yaml` | Gitea service |
| `apps/shared/gitea/Ingress.yaml` | Gitea ingress |
| `apps/shared/gitea/PVC.yaml` | Gitea data PVC |
| `apps/shared/gitea/Secret.yaml` | Gitea secrets |

**Coder**
| File | Purpose |
|------|---------|
| `apps/shared/coder/Deployment.yaml` | Coder deployment |
| `apps/shared/coder/Service.yaml` | Coder service |
| `apps/shared/coder/Ingress.yaml` | Coder ingress |
| `apps/shared/coder/PVC.yaml` | Coder data PVC |
| `apps/shared/coder/Secret.yaml` | Coder secrets |

#### Phase 4: AI Services

**Langflow**
| File | Purpose |
|------|---------|
| `apps/shared/langflow/Deployment.yaml` | Langflow deployment |
| `apps/shared/langflow/Service.yaml` | Langflow service |
| `apps/shared/langflow/Ingress.yaml` | Langflow ingress |
| `apps/shared/langflow/PVC.yaml` | Langflow data PVC |

**Kokoro TTS**
| File | Purpose |
|------|---------|
| `apps/shared/kokoro/Deployment.yaml` | Kokoro deployment |
| `apps/shared/kokoro/Service.yaml` | Kokoro service |
| `apps/shared/kokoro/Ingress.yaml` | Kokoro ingress |

**Docling**
| File | Purpose |
|------|---------|
| `apps/shared/docling/Deployment.yaml` | Docling deployment |
| `apps/shared/docling/Service.yaml` | Docling service |
| `apps/shared/docling/Ingress.yaml` | Docling ingress |

**SearXNG**
| File | Purpose |
|------|---------|
| `apps/shared/searxng/Deployment.yaml` | SearXNG deployment |
| `apps/shared/searxng/Service.yaml` | SearXNG service |
| `apps/shared/searxng/Ingress.yaml` | SearXNG ingress |
| `apps/shared/searxng/ConfigMap.yaml` | SearXNG configuration |

**Perplexica**
| File | Purpose |
|------|---------|
| `apps/shared/perplexica/Deployment.yaml` | Perplexica deployment |
| `apps/shared/perplexica/Service.yaml` | Perplexica service |
| `apps/shared/perplexica/Ingress.yaml` | Perplexica ingress |

**SurfSense**
| File | Purpose |
|------|---------|
| `apps/shared/surfsense/Deployment.yaml` | SurfSense deployment |
| `apps/shared/surfsense/Service.yaml` | SurfSense service |
| `apps/shared/surfsense/Ingress.yaml` | SurfSense ingress |

#### Phase 5: Productivity Services

**AppFlowy**
| File | Purpose |
|------|---------|
| `apps/shared/appflowy/Deployment.yaml` | AppFlowy deployment |
| `apps/shared/appflowy/Service.yaml` | AppFlowy service |
| `apps/shared/appflowy/Ingress.yaml` | AppFlowy ingress |
| `apps/shared/appflowy/PVC.yaml` | AppFlowy data PVC |

**LinkWarden**
| File | Purpose |
|------|---------|
| `apps/shared/linkwarden/Deployment.yaml` | LinkWarden deployment |
| `apps/shared/linkwarden/Service.yaml` | LinkWarden service |
| `apps/shared/linkwarden/Ingress.yaml` | LinkWarden ingress |
| `apps/shared/linkwarden/PVC.yaml` | LinkWarden data PVC |
| `apps/shared/linkwarden/Secret.yaml` | LinkWarden secrets |

**Homebox**
| File | Purpose |
|------|---------|
| `apps/shared/homebox/Deployment.yaml` | Homebox deployment |
| `apps/shared/homebox/Service.yaml` | Homebox service |
| `apps/shared/homebox/Ingress.yaml` | Homebox ingress |
| `apps/shared/homebox/PVC.yaml` | Homebox data PVC |

**Home Assistant**
| File | Purpose |
|------|---------|
| `apps/shared/home-assistant/Deployment.yaml` | Home Assistant deployment |
| `apps/shared/home-assistant/Service.yaml` | Home Assistant service |
| `apps/shared/home-assistant/Ingress.yaml` | Home Assistant ingress |
| `apps/shared/home-assistant/PVC.yaml` | Home Assistant data PVC |

**Kasm Workspaces**
| File | Purpose |
|------|---------|
| `apps/shared/kasm/Namespace.yaml` | Kasm namespace |
| `apps/shared/kasm/Deployment.yaml` | Kasm deployment |
| `apps/shared/kasm/Service.yaml` | Kasm service |
| `apps/shared/kasm/Ingress.yaml` | Kasm ingress |

#### Phase 6: Infrastructure Completion

**AWS Terraform Provider**
| File | Purpose |
|------|---------|
| `infrastructure/terraform/providers/aws/vpc.tf` | VPC configuration |
| `infrastructure/terraform/providers/aws/subnets.tf` | Subnet configuration |
| `infrastructure/terraform/providers/aws/security-groups.tf` | Security groups |
| `infrastructure/terraform/providers/aws/iam.tf` | IAM roles and policies |
| `infrastructure/terraform/providers/aws/instances.tf` | EC2 instances |
| `infrastructure/terraform/providers/aws/routing.tf` | Route tables and gateways |

**GCP Terraform Provider**
| File | Purpose |
|------|---------|
| `infrastructure/terraform/providers/gcp/vpc.tf` | VPC configuration |
| `infrastructure/terraform/providers/gcp/subnets.tf` | Subnet configuration |
| `infrastructure/terraform/providers/gcp/firewall.tf` | Firewall rules |
| `infrastructure/terraform/providers/gcp/service-account.tf` | Service account |
| `infrastructure/terraform/providers/gcp/instances.tf` | GCE instances |

**Ansible Roles**
| File | Purpose |
|------|---------|
| `infrastructure/ansible/roles/pfsense/tasks/main.yml` | pfSense configuration |
| `infrastructure/ansible/roles/pfsense/templates/pfsense.conf.j2` | pfSense config template |
| `infrastructure/ansible/roles/tailscale/tasks/main.yml` | Tailscale installation |
| `infrastructure/ansible/roles/wireguard/tasks/main.yml` | WireGuard configuration |
| `infrastructure/ansible/roles/wireguard/templates/wireguard.conf.j2` | WireGuard config template |

### Existing Files to Be Modified

| File                                             | Changes                                  |
| ------------------------------------------------ | ---------------------------------------- |
| `apps/shared/implementation_status.md`           | Update all services to completed         |
| `apps/shared/langflow/Deployment.yaml`           | Convert from Helm template to plain YAML |
| `infrastructure/terraform/providers/aws/main.tf` | Add VPC, security groups, instances      |
| `infrastructure/terraform/providers/gcp/main.tf` | Add VPC, firewall, instances             |
| `infrastructure/terraform/variables.tf`          | Add AWS/GCP networking variables         |
| `infrastructure/ansible/playbooks/site.yml`      | Add pfSense, Tailscale, WireGuard        |

---

## Functions

### Shell Functions for Environment Setup

```bash
# config/setup-environment.sh
#!/bin/bash
# Setup environment-specific configurations

setup_sealed_secrets_key() {
    local env=$1
    local key_file="config/environments/${env}/sealed-secrets-key.yaml"

    if [[ ! -f "$key_file" ]]; then
        echo "Generating Sealed Secrets key for ${env}..."
        kubectl create namespace sealed-secrets 2>/dev/null
        kubectl create secret generic sealed-secrets-keys \
            --from-literal=sealed-secret-key.pem=$(openssl rsa -outform PEM | base64 | tr -d '\n') \
            --from-literal=sealed-secretpub-key.pem=$(openssl rsa -pubout -outform PEM | base64 | tr -d '\n') \
            -n sealed-secrets -o yaml > "$key_file"
    fi
}
```

### Terraform Functions

```hcl
# infrastructure/terraform/modules/networking/vpc.tf
locals {
  vpc_tags = merge(var.common_tags, {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  })
}
```

---

## Classes

### Kubernetes Resource Classes

#### Storage Class Hierarchy

```
StorageClasses:
├── longhorn (Primary)
│   ├── Provisioner: driver.longhorn.io
│   ├── Replicas: 3
│   └── Use Case: Most stateful workloads
├── nfs (Secondary)
│   ├── Provisioner: nfs.csi.k8s.io
│   └── Use Case: Large files, backups
└── minio (Object)
    ├── Provisioner: internal
    └── Use Case: S3-compatible storage
```

#### Database Class (CloudNativePG)

```
CloudNativePG Cluster:
├── Instances: 3
├── Replication: Synchronous
├── Storage: 50Gi Longhorn
└── PostgreSQL Version: 16.2
```

---

## Dependencies

### New Kubernetes Dependencies

| Dependency       | Version | Purpose                      |
| ---------------- | ------- | ---------------------------- |
| Longhorn         | 1.6.0   | Primary block storage        |
| NFS CSI Driver   | 4.0.0   | NFS storage support          |
| MinIO Operator   | 5.0.0   | S3 object storage            |
| MetalLB          | 0.14.0  | LoadBalancer provider        |
| cert-manager     | 1.14.0  | TLS certificate management   |
| CloudNativePG    | 1.23.0  | PostgreSQL operator          |
| Sealed Secrets   | 2.14.0  | Git-safe encrypted secrets   |
| External Secrets | 0.9.13  | External secret sync         |
| Velero           | 1.13.0  | Backup and restore           |
| Prometheus       | 2.50.0  | Metrics collection           |
| Grafana          | 10.3.0  | Dashboards and visualization |
| Loki             | 2.9.0   | Log aggregation              |
| Promtail         | 2.9.0   | Log collection               |

### New Terraform Dependencies

| Provider  | Version | Purpose              |
| --------- | ------- | -------------------- |
| aws       | ~> 5.0  | AWS infrastructure   |
| google    | ~> 5.0  | GCP infrastructure   |
| tailscale | ~> 0.8  | Tailscale networking |

### New Ansible Dependencies

| Collection        | Version | Purpose           |
| ----------------- | ------- | ----------------- |
| community.general | latest  | pfSense module    |
| ansible.netcommon | latest  | Network utilities |

---

## Testing

### Test File Requirements

#### Kubernetes Manifest Tests

```bash
# tests/kubernetes/test_storage_classes.sh
#!/bin/bash
# Verify storage classes are properly configured

test_longhorn_storage_class() {
    kubectl get sc longhorn -o jsonpath='{.provisioner}' | grep -q "driver.longhorn.io"
}

test_nfs_storage_class() {
    kubectl get sc nfs -o jsonpath='{.provisioner}' | grep -q "nfs.csi.k8s.io"
}
```

#### Integration Tests

```bash
# tests/integration/test_cloudnativepg.sh
#!/bin/bash
# Test CloudNativePG cluster availability

test_postgresql_cluster() {
    kubectl cnpg connect postgres-ha -c psql -c "SELECT 1" | grep -q "1"
}
```

#### Terraform Tests

```bash
# tests/infrastructure/test_aws_vpc.sh
#!/bin/bash
# Verify AWS VPC configuration

test_aws_vpc_exists() {
    aws ec2 describe-vpcs --filters "Name=tag:Name,Values=inkorporated-vpc" | grep -q "Vpcs"
}
```

### Existing Test Modifications

| Test File                                | Modifications                     |
| ---------------------------------------- | --------------------------------- |
| `tests/kubernetes/test_manifests.sh`     | Add storage class validation      |
| `tests/config/test_config_validation.sh` | Add Sealed Secrets key validation |
| `tests/integration/test_authentik.sh`    | Add PostgreSQL connectivity test  |

---

## Implementation Order

### Wave 1: Storage Foundation (Priority: Critical)

**Order of Operations:**

1. Longhorn Namespace → CRDs → Deployment → StorageClass
2. NFS CSI Namespace → Deployment → StorageClass
3. MinIO Namespace → Deployment → Service → PVC

**Validation:**

```bash
kubectl get sc | grep -E "longhorn|nfs"
kubectl get pvc -n minio
```

### Wave 2: Networking Foundation (Priority: Critical)

**Order of Operations:**

1. MetalLB Namespace → Deployment → ConfigMap (IP pool)
2. cert-manager Namespace → Deployment → Issuer → Certificate

**Validation:**

```bash
kubectl get cm -n metallb ip-address-pool
kubectl get issuer -n cert-manager
```

### Wave 3: Database Foundation (Priority: Critical)

**Order of Operations:**

1. CloudNativePG CRDs → Operator → Cluster
2. Wait for PostgreSQL cluster to be ready

**Validation:**

```bash
kubectl cnpg connect postgres-ha -c "SELECT version();"
```

### Wave 4: Secrets Management (Priority: High)

**Order of Operations:**

1. Sealed Secrets Namespace → Controller → Generate keys per environment
2. External Secrets Namespace → Operator → Vault Provider

**Validation:**

```bash
kubectl get secret -n sealed-secrets sealed-secrets-keys
```

### Wave 5: Backups (Priority: High)

**Order of Operations:**

1. Velero Namespace → Deployment → BackupStorageLocation → Schedule

**Validation:**

```bash
velero backup locations get
velero schedule get
```

### Wave 6: Observability (Priority: Medium)

**Order of Operations:**

1. Prometheus Namespace → Deployment → Service → ServiceMonitor
2. Grafana Namespace → Deployment → Service → Ingress → ConfigMap
3. Loki Namespace → Deployment → Service
4. Promtail Namespace → Deployment → ConfigMap

**Validation:**

```bash
kubectl port-forward svc/prometheus -n prometheus 9090:80
kubectl port-forward svc/grafana -n grafana 3000:80
```

### Wave 7: Development Platform (Priority: Medium)

**Order of Operations:**

1. Gitea Namespace → Deployment → Service → Ingress → PVC
2. Coder Namespace → Deployment → Service → Ingress → PVC

**Validation:**

```bash
kubectl get ingress -n gitea
kubectl get ingress -n coder
```

### Wave 8: AI Services (Priority: Low)

**Order of Operations:**

1. Langflow → Kokoro → Docling → SearXNG → Perplexica → SurfSense

**Validation:**

```bash
for svc in langflow kokoro docling searxng perplexica surfsense; do
    kubectl get ingress -n "$svc"
done
```

### Wave 9: Productivity Services (Priority: Low)

**Order of Operations:**

1. AppFlowy → LinkWarden → Homebox → Home Assistant → Kasm

**Validation:**

```bash
for svc in appflowy linkwarden homebox homeassistant kasm; do
    kubectl get ingress -n "$svc"
done
```

### Wave 10: Infrastructure Completion (Priority: Medium)

**Order of Operations:**

1. Complete AWS Terraform (VPC → Subnets → Security Groups → IAM → Instances)
2. Complete GCP Terraform (VPC → Subnets → Firewall → Service Account → Instances)
3. Ansible pfSense role
4. Tailscale + WireGuard hybrid networking

**Validation:**

```bash
terraform plan -var-file=terraform.tfvars
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check
```

---

## Appendix: Service Dependency Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                    Inkorporated Services                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Wave 1 (Storage)        Wave 2 (Networking)                   │
│  ├─ Longhorn ───────────►├─ MetalLB                            │
│  ├─ NFS CSI              │├─ cert-manager                       │
│  └─ MinIO ◄─────────────┤                                     │
│                                                                 │
│  Wave 3 (Database)       Wave 4 (Secrets)                      │
│  ├─ CloudNativePG ──────►├─ Sealed Secrets                     │
│                         │└─ External Secrets                   │
│                                                                 │
│  Wave 5 (Backups)        Wave 6 (Observability)               │
│  ├─ Velero ◄────────────┼─┬─ Prometheus                        │
│                         │├─┼─ Grafana                          │
│                         │└─┴─ Loki/Promtail                    │
│                                                                 │
│  Wave 7 (Dev)           Wave 8 (AI)                            │
│  ├─ Gitea               │├─ Langflow                           │
│  └─ Coder               │├─ Kokoro → Docling                   │
│                         │├─ SearXNG                             │
│                         │├─ Perplexica                          │
│                         │└─ SurfSense                           │
│                                                                 │
│  Wave 9 (Productivity)  Wave 10 (Infra)                        │
│  ├─ AppFlowy            │├─ AWS Terraform                       │
│  ├─ LinkWarden          │├─ GCP Terraform                       │
│  ├─ Homebox             │├─ pfSense Ansible                     │
│  ├─ Home Assistant      │└─ Tailscale/WireGuard                │
│  └─ Kasm                                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

_Generated: 2026-04-11_
_Author: Claude Sonnet 4.6_
 Completion (Priority: Medium)

**Order of Operations:**

1. Complete AWS Terraform (VPC → Subnets → Security Groups → IAM → Instances)
2. Complete GCP Terraform (VPC → Subnets → Firewall → Service Account → Instances)
3. Ansible pfSense role
4. Tailscale + WireGuard hybrid networking

**Validation:**

```bash
terraform plan -var-file=terraform.tfvars
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check
```

---

## Appendix: Service Dependency Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                    Inkorporated Services                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Wave 1 (Storage)        Wave 2 (Networking)                   │
│  ├─ Longhorn ───────────►├─ MetalLB                            │
│  ├─ NFS CSI              │├─ cert-manager                       │
│  └─ MinIO ◄─────────────┤                                     │
│                                                                 │
│  Wave 3 (Database)       Wave 4 (Secrets)                      │
│  ├─ CloudNativePG ──────►├─ Sealed Secrets                     │
│                         │└─ External Secrets                   │
│                                                                 │
│  Wave 5 (Backups)        Wave 6 (Observability)               │
│  ├─ Velero ◄────────────┼─┬─ Prometheus                        │
│                         │├─┼─ Grafana                          │
│                         │└─┴─ Loki/Promtail                    │
│                                                                 │
│  Wave 7 (Dev)           Wave 8 (AI)                            │
│  ├─ Gitea               │├─ Langflow                           │
│  └─ Coder               │├─ Kokoro → Docling                   │
│                         │├─ SearXNG                             │
│                         │├─ Perplexica                          │
│                         │└─ SurfSense                           │
│                                                                 │
│  Wave 9 (Productivity)  Wave 10 (Infra)                        │
│  ├─ AppFlowy            │├─ AWS Terraform                       │
│  ├─ LinkWarden          │├─ GCP Terraform                       │
│  ├─ Homebox             │├─ pfSense Ansible                     │
│  ├─ Home Assistant      │└─ Tailscale/WireGuard                │
│  └─ Kasm                                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

*Generated: 2026-04-11*
*Author: Claude Sonnet 4.6*
