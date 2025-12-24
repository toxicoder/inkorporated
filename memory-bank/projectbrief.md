# Project Brief

## Core Requirements and Goals

This document defines the fundamental scope, requirements, and goals of the project. It serves as the foundation for all other documentation in the memory bank.

## Project Scope
- Implement the inkorporated homelab infrastructure as described in the technical design document
- Create a fully self-hosted, open-source internal work environment
- Deploy all services in a k3s Kubernetes cluster with GitOps management via ArgoCD
- Implement security through centralized authentication (Authentik SSO/OIDC) and network security (pfSense)
- Enable zero-trust access via Cloudflare Tunnel (cloudflared)

## Key Objectives
- Deliver a complete, integrated, open-source internal work environment
- Ensure secure, private, and powerful infrastructure with professional-grade networking
- Provide centralized authentication and access control
- Implement comprehensive observability and monitoring
- Enable seamless user experience with a centralized dashboard

## Technical Constraints
- All components must be free and open source (FOSS)
- Infrastructure must run on a single k3s cluster
- Services must be protected by centralized authentication
- All services must be routed through Traefik with unique subdomains
- Storage must be provided by Longhorn and NFS CSI driver
- Backups must be handled by Velero with MinIO as target
- Network security must be handled by pfSense VM

# task_progress
- [x] Analyze technical design document
- [x] Review current project structure
- [x] Initialize project documentation with proper context
- [x] Create comprehensive implementation plan
- [x] Set up core infrastructure components
- [x] Deploy cloudflared tunnel service
- [x] Implement remaining services in phases


# task_progress RECOMMENDED

When starting a new task, it is recommended to include a todo list using the task_progress parameter.


1. Include a todo list using the task_progress parameter in your next tool call
2. Create a comprehensive checklist of all steps needed
3. Use markdown format: - [ ] for incomplete, - [x] for complete

**Benefits of creating a todo/task_progress list now:**
	- Clear roadmap for implementation
	- Progress tracking throughout the task
	- Nothing gets forgotten or missed
	- Users can see, monitor, and edit the plan

**Example structure:**```
- [ ] Analyze requirements
- [ ] Set up necessary files
- [ ] Implement main functionality
- [ ] Handle edge cases
- [ ] Test the implementation
- [ ] Verify results```

Keeping the task_progress list updated helps track progress and ensures nothing is missed.
