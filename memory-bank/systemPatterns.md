# System Patterns

## System Architecture

This document outlines the system architecture, key technical decisions, and design patterns in use.

## Overall Architecture
- Kubernetes cluster running k3s as the container orchestration platform
- GitOps deployment using ArgoCD for infrastructure and application management
- Centralized authentication through Authentik with OIDC support
- Ingress control via Traefik with forward-auth middleware
- Zero-trust access enabled through Cloudflare Tunnel (cloudflared)
- Network security provided by pfSense VM
- Storage solutions including Longhorn and NFS CSI driver
- Backup and disaster recovery with Velero and MinIO
- Observability stack with Prometheus, Grafana, and Loki

## Key Technical Decisions
- Use of k3s for lightweight Kubernetes deployment
- Implementation of GitOps with ArgoCD for declarative infrastructure
- Centralized authentication with Authentik for SSO
- Traefik as ingress controller with forward-auth for security
- Cloudflare Tunnel for zero-trust external access
- Longhorn for distributed block storage
- NFS CSI driver for Synology NAS integration
- MinIO for object storage and backup target
- Velero for backup and restore capabilities
- Monitoring with kube-prometheus-stack

## Design Patterns in Use
- Service-oriented architecture with proper namespace separation
- GitOps deployment pattern for infrastructure as code
- Zero-trust security model with Cloudflare Tunnel
- Centralized authentication with OIDC
- Helm chart pattern for application deployment
- Kubernetes manifest pattern for custom resources
- Configuration management through ConfigMaps and Secrets
- Resource quota and limit patterns for resource management

## Component Relationships
- pfSense VM provides network security and routing
- k3s cluster hosts all applications and services
- Traefik handles ingress and TLS termination
- Authentik provides authentication and authorization
- Cloudflare Tunnel enables secure external access
- Longhorn and NFS CSI provide persistent storage
- MinIO serves as backup and object storage target
- Velero handles backup and disaster recovery
- Monitoring stack provides metrics and logging

## Critical Implementation Paths
- Infrastructure provisioning through Terraform and Ansible
- GitOps deployment via ArgoCD
- Service deployment with proper namespace organization
- Authentication configuration with Authentik
- Storage setup with Longhorn and NFS CSI
- Backup configuration with Velero
- Monitoring stack deployment
- Cloudflare Tunnel setup and configuration

# task_progress
- [x] Analyze technical design document
- [x] Review current project structure
- [x] Initialize project documentation with proper context
- [ ] Create comprehensive implementation plan
- [ ] Set up core infrastructure components
- [ ] Deploy cloudflared tunnel service
- [ ] Implement remaining services in phases
