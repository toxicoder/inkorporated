# Technical Context

## Technologies and Development Setup

This document covers the technologies used, development setup, and technical constraints.

## Technologies Used
- **Container Orchestration**: Kubernetes (k3s)
- **Deployment Management**: ArgoCD (GitOps)
- **Authentication**: Authentik (OIDC + SSO)
- **Ingress Controller**: Traefik with forward-auth
- **Zero-trust Access**: Cloudflare Tunnel (cloudflared)
- **Network Security**: pfSense VM
- **Storage**: Longhorn (block storage), NFS CSI driver (Synology NAS)
- **Backup & DR**: Velero with MinIO
- **Monitoring**: kube-prometheus-stack (Prometheus, Grafana, Loki)
- **Service Mesh**: None (direct service-to-service communication)
- **CI/CD**: GitOps via ArgoCD
- **Infrastructure as Code**: Terraform, Ansible
- **Container Images**: Various FOSS images from Docker Hub

## Development Setup
- **Local Environment**: VS Code with devcontainer support
- **Tooling**: kubectl, helm, terraform, ansible, cloudflared CLI
- **Deployment Process**: GitOps with ArgoCD synchronization
- **Testing**: Manual testing of services and integrations
- **Debugging**: kubectl logs, kubectl describe, Grafana dashboards

## Technical Constraints
- All components must be free and open source (FOSS)
- Infrastructure must run on a single k3s cluster
- Services must be protected by centralized authentication
- All services must be routed through Traefik with unique subdomains
- Storage must be provided by Longhorn and NFS CSI driver
- Backups must be handled by Velero with MinIO as target
- Network security must be handled by pfSense VM
- Zero-trust access must be enabled via Cloudflare Tunnel
- Configuration must support environment-specific variables for domain flexibility

## Dependencies
- **Primary Dependencies**: k3s, ArgoCD, Traefik, Authentik, Longhorn, MinIO, Velero
- **Development Dependencies**: terraform, ansible, helm, kubectl, cloudflared
- **Runtime Dependencies**: Various FOSS applications (Rocket.Chat, Open WebUI, etc.)
- **Security Dependencies**: cert-manager, MetalLB, Cloudflare Tunnel

## Tool Usage Patterns
- **CI/CD Pipeline**: GitOps with ArgoCD for infrastructure and application deployment
- **Code Review**: Manual review of GitOps manifests
- **Debugging**: Kubernetes debugging with kubectl, service logs, and monitoring
- **Monitoring**: Prometheus metrics, Grafana dashboards, Loki logs
- **Security**: Authentik SSO, SealedSecrets for sensitive data, Cloudflare Tunnel
- **Configuration Management**: Environment variable configuration with centralized ConfigMap approach

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
