# Hybrid Cloud Architecture

## Overview

The Inkorporated homelab now utilizes a Hybrid Cloud architecture, combining the control and persistence of on-premises hardware with the scalability of public cloud providers.

## Topology

### On-Premises (Proxmox)
*   **Role**: Primary control plane, persistent storage, stable workloads.
*   **Nodes**: 5 Proxmox hosts running VMs and LXC containers.
*   **Kubernetes**: k3s server (master) nodes and worker nodes.
*   **Storage**: Longhorn (block) and NFS (file).

### Cloud (AWS / GCP)
*   **Role**: Burst capacity, temporary testing, high-availability fallover (future).
*   **Nodes**: EC2 instances or GCE VMs.
*   **Kubernetes**: k3s agent (worker) nodes joined to the on-prem master.
*   **Storage**: Cloud-native block storage (EBS gp2/gp3, GCE standard/pd-ssd).

## Networking
*   **VPN**: A mesh VPN (e.g., Tailscale or Wireguard) connects all nodes.
*   **Service Discovery**: Internal DNS or K8s Service discovery works across the mesh.

## GitOps & Application Management
*   **ArgoCD**: Manages deployments across all environments.
*   **ApplicationSets**: Dynamically target clusters/environments.
    *   `on-prem`: Targets local cluster, sets storageClass to `longhorn`.
    *   `cloud`: Targets cloud nodes (via node selectors or separate clusters), sets storageClass to `gp2`.

## Scaling (Bursting)
*   Scripts in `cloud/burst.sh` monitor load.
*   When thresholds are met, `terraform apply` is triggered with a higher count for cloud instances.
*   New nodes automatically join the k3s cluster via `cloud-init` and Ansible.
