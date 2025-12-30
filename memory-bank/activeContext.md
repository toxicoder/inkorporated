# Active Context

## Current Work Focus

This document tracks the current work focus, recent changes, and active decisions that are relevant to ongoing development.

## Recent Changes

- Implemented deployment files for all services in the apps/shared directory
- Updated all services to use configurable domain variables from config files
- Project renamed from "devset" to "inkorporated" (confirmed)
- Centralized configuration management system for domain variables implemented

## Next Steps

- Configure Authentik for centralized authentication
- Deploy monitoring and observability stack
- Begin physical infrastructure validation
- Create bootstrap repository with Terraform/Ansible
- Set up workstation tools and dependencies
- Complete cloudflared tunnel token integration
- Deploy remaining services according to the implementation plan

## Active Decisions and Considerations

- Using k3s cluster for all services as specified in design
- Implementing GitOps with ArgoCD for deployment management
- Leveraging Cloudflare Tunnel for zero-trust access
- Utilizing Traefik as ingress controller with forward-auth
- Implementing centralized authentication via Authentik
- Using Longhorn and NFS CSI for storage solutions
- Deploying Velero for backup and disaster recovery
- Following the phased approach from the technical design document
- Project renamed from "devset" to "inkorporated" - confirmed
- Cloudflared deployment structure complete - waiting for token
- Implemented environment variable configuration for domain flexibility
- Centralized configuration management system in place

## Important Patterns and Preferences

- Following the phased implementation approach (Phase 1-5)
- Using Helm charts and Kubernetes manifests for deployments
- Implementing proper namespace organization
- Leveraging GitOps principles for configuration management
- Using SealedSecrets for sensitive data handling
- Implementing proper RBAC and network policies
- Following the service grouping and naming conventions from the design
- Maintaining correct project naming throughout all documentation
- Cloudflared deployment follows technical design specifications
- Implemented environment variable configuration for domain flexibility
- Centralized configuration management system in place

## task_progress

- [x] Analyze technical design document
- [x] Review current project structure
- [x] Initialize project documentation with proper context
- [x] Create comprehensive implementation plan
- [x] Set up core infrastructure components
- [x] Deploy cloudflared tunnel service
- [x] Implement remaining services in phases
- [x] Update activeContext.md to reflect current state