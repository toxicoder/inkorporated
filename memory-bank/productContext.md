# Product Context

## Purpose and Problem Statement

This document explains why this project exists, what problems it solves, and how it should work from a user experience perspective.

## Why This Project Exists
- To create a fully self-hosted, open-source internal work environment
- To provide a centralized platform for collaboration, productivity, and AI tools
- To offer secure, private infrastructure with professional-grade networking
- To enable zero-trust access to services without exposing ports publicly
- To provide comprehensive observability and monitoring for all services

## How It Should Work
- Users access services through a centralized dashboard (Homepage app)
- All services are protected by centralized authentication (Authentik SSO/OIDC)
- Services are routed through Traefik with unique subdomains (service.overeazy.io)
- Network security is handled by pfSense VM with firewall rules and VPN termination
- Zero-trust access is enabled via Cloudflare Tunnel (cloudflared)
- All data is backed up using Velero with MinIO as the backup target
- Network segmentation is implemented through a multi-zone topology for security isolation

## User Experience Goals
- Intuitive single-pane access through the Homepage dashboard
- Seamless SSO experience across all services
- Consistent user interface with grouped shortcuts by category
- Reliable and secure access to all internal tools
- Easy navigation to all hosted applications

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