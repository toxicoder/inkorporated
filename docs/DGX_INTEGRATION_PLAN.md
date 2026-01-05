---
layout: page
title: "DGX Integration Plan"
permalink: /DGX_INTEGRATION_PLAN.html
---

# NVIDIA DGX Spark Integration Plan

## Overview
This document outlines the technical implementation plan for integrating two NVIDIA DGX Spark systems into the Inkorporated homelab infrastructure. The DGX Spark systems, equipped with NVIDIA Grace CPU and Blackwell GPU architecture, will be added as dedicated GPU-accelerated worker nodes to the existing k3s Kubernetes cluster.

## Prerequisites
Before integrating DGX Spark systems, the following infrastructure components must be deployed:
1. Longhorn Storage (Block storage for persistent volumes)
2. MetalLB (LoadBalancer provider for external services)
3. Observability Stack (Prometheus/Grafana/Loki for monitoring)
4. cert-manager (TLS automation)
5. MinIO Object Storage (Backup target)

## Integration Phases

### Phase 1: Prerequisite Infrastructure Deployment
This phase aligns with Phase 4 of the current implementation plan in progress.md.

#### Task 4.01: Deploy NFS CSI Driver
- **Status**: Not Started
- **Purpose**: Provide NFS-based persistent volumes for shared storage
- **Implementation**: Deploy NFS CSI driver using Helm chart
- **Resources**: 
  - NFS CSI Driver Helm chart
  - NFS server configuration

#### Task 4.02: Deploy Longhorn Storage
- **Status**: Not Started  
- **Purpose**: Distributed block storage for GPU workloads
- **Implementation**: 
  - Install Longhorn via Helm chart
  - Configure storage class for GPU workloads
  - Set up Longhorn volume replication
- **Resources**: 
  - Longhorn Helm chart
  - Storage configuration for DGX local SSDs

#### Task 4.03: Deploy MinIO Object Storage
- **Status**: Not Started
- **Purpose**: S3-compatible object storage for backups and AI datasets
- **Implementation**:
  - Deploy MinIO via Helm chart
  - Configure MinIO as backup target
  - Set up persistent storage
- **Resources**:
  - MinIO Helm chart
  - NFS PVC for data persistence

#### Task 4.04: Deploy cert-manager
- **Status**: Not Started
- **Purpose**: TLS certificate automation for secure communication
- **Implementation**:
  - Install cert-manager via Helm chart
  - Configure ClusterIssuer for Let's Encrypt
- **Resources**:
  - cert-manager Helm chart
  - ACME configuration

#### Task 4.05: Deploy MetalLB
- **Status**: Not Started
- **Purpose**: LoadBalancer service type for external access
- **Implementation**:
  - Install MetalLB via Helm chart
  - Configure IP address pool for external services
- **Resources**:
  - MetalLB Helm chart
  - IP address configuration

#### Task 4.06: Deploy Observability Stack
- **Status**: Not Started
- **Purpose**: Monitor GPU metrics and system performance
- **Implementation**:
  - Deploy kube-prometheus-stack (Prometheus, Grafana, Loki)
  - Configure DCGM exporter for GPU metrics
  - Set up monitoring dashboards for AI workloads
- **Resources**:
  - Prometheus/Grafana Helm chart
  - DCGM exporter configuration

### Phase 2: DGX Spark Integration

#### Task 4.x: Integrate DGX Spark Systems as Worker Nodes

##### Physical Setup
1. **Network Configuration**
   - Connect each DGX Spark system to the LAN switch via Ethernet
   - Configure static IPs in management VLAN (e.g., 192.168.1.101/102 for DGX1/DGX2)
   - Connect DGX nodes directly with two OSFP cables (200 Gbps each, 400 Gbps total)
   - Assign private subnet for direct communication (e.g., 192.168.100.0/24)
   - Configure jumbo frames (MTU=9000) for high throughput
   - Bond interfaces for redundancy (Linux bonding driver)

2. **Security Configuration**
   - Update pfSense firewall rules to allow:
     - k3s API access (6443)
     - etcd communication (2379-2380)
     - Node ports (30000-32767)
   - Configure DNS entries for DGX nodes (e.g., dgx-spark-1.inkorporated.local)
   - Implement network segmentation per multi-zone topology

##### Software Installation

1. **k3s Agent Installation**
   - Extend existing Ansible playbooks in `infrastructure/ansible/`
   - Join DGX systems as worker nodes to the k3s cluster
   - Install required dependencies:
     ```bash
     apt update && apt upgrade -y
     apt install curl iptables-persistent -y
     ```

2. **Node Configuration**
   - Label nodes for GPU scheduling:
     ```bash
     kubectl label nodes dgx-spark-1 node-role.kubernetes.io/ai-gpu=true nvidia.com/gpu=true
     kubectl label nodes dgx-spark-2 node-role.kubernetes.io/ai-gpu=true nvidia.com/gpu=true
     ```
   - Taint nodes for GPU workloads:
     ```bash
     kubectl taint nodes dgx-spark-1 dedicated=gpu:NoSchedule
     kubectl taint nodes dgx-spark-2 dedicated=gpu:NoSchedule
     ```

##### GPU Operator Deployment

1. **NVIDIA GPU Operator Installation**
   - Add NVIDIA Helm repository:
     ```bash
     helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
     helm repo update
     ```
   - Deploy GPU Operator:
     ```bash
     helm install gpu-operator nvidia/gpu-operator \
       --set driver.enabled=true \
       --set devicePlugin.enabled=true \
       --set dcgm.enabled=true \
       --set dcgmExporter.enabled=true \
       --namespace nvidia-gpu-operator \
       --create-namespace
     ```

2. **Verification**
   - Verify GPU operator pods:
     ```bash
     kubectl get pods -n nvidia-gpu-operator
     ```
   - Test GPU detection:
     ```bash
     kubectl run -it --rm --image=nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
     ```

### Phase 3: AI Workload Configuration

#### Update Existing AI Services to Use GPU Nodes

1. **Ollama Deployment**
   - Modify deployment to use node selector:
     ```yaml
     spec:
       template:
         spec:
           nodeSelector:
             node-role.kubernetes.io/ai-gpu: "true"
           tolerations:
           - key: "dedicated"
             operator: "Equal"
             value: "gpu"
             effect: "NoSchedule"
     ```

2. **Open WebUI Deployment**
   - Apply same node selector configuration
   - Configure GPU resources in deployment spec:
     ```yaml
     resources:
       limits:
         nvidia.com/gpu: 1
       requests:
         nvidia.com/gpu: 1
     ```

3. **Langflow Deployment**
   - Configure node affinity and GPU resources
   - Update deployment to target GPU worker nodes

#### Storage Integration

1. **Longhorn Extension**
   - Deploy Longhorn agent on DGX nodes
   - Configure local SSDs for volume replicas
   - Create Longhorn storage class for AI workloads

2. **Persistent Volume Claims**
   - Update AI services to use Longhorn PVCs for model storage
   - Configure storage size requirements for different AI workloads

### Phase 4: Monitoring and Testing

#### GPU Metrics Monitoring
1. **DCGM Exporter Configuration**
   - Configure DCGM exporter to collect GPU metrics
   - Set up Prometheus scrape configuration
   - Create Grafana dashboards for GPU utilization

2. **Performance Testing**
   - Deploy test CUDA workloads to verify GPU functionality
   - Run distributed training jobs to test inter-node communication
   - Validate storage performance with AI datasets

#### Security Implementation
1. **RBAC Policies**
   - Create role-based access controls for GPU resources
   - Implement network policies for GPU node communication
   - Configure Authentik integration for admin access

### Implementation Timeline
- **Week 1**: Complete prerequisite infrastructure deployment (Longhorn, MetalLB, cert-manager, Observability)
- **Week 2**: Physical setup and k3s agent installation on DGX systems
- **Week 3**: GPU Operator deployment and AI service configuration
- **Week 4**: Testing and performance validation

### Risk Mitigation
1. **Compatibility Risks**
   - Test DGX OS compatibility with k3s agent
   - Verify NVIDIA driver versions with k3s cluster

2. **Performance Bottlenecks**
   - Monitor network throughput with iperf3 tests
   - Validate GPU memory allocation and utilization

3. **Rollback Strategy**
   - Implement node draining for maintenance
   - Maintain backup of existing configurations
   - Document rollback procedures for each phase

### Resource Requirements
- **Hardware**: 2x NVIDIA DGX Spark systems (Grace CPU + Blackwell GPU)
- **Network**: 10/25/100 Gbps Ethernet connectivity, 400 Gbps direct OSFP links
- **Software**: 
  - k3s cluster (existing)
  - NVIDIA GPU Operator Helm chart
  - Longhorn storage operator
  - Prometheus/Grafana monitoring stack

### Success Criteria
- DGX nodes successfully join k3s cluster as worker nodes
- GPU Operator deployed and functional
- AI services can be scheduled on GPU nodes
- GPU metrics available through monitoring stack
- Performance benchmarks meet expected throughput requirements
