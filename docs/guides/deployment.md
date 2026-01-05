---
layout: doc
---

# Deployment & Operations

## Deployment Process
1. **Terraform** → **Ansible bootstrap** (including pfSense VM)
2. **Configure pfSense** post-deploy (interfaces, rules, VPN)
3. **ArgoCD sync** (wave order: storage → DBs → Authentik → backends → frontends)
4. **Post-deploy** configuration (Authentik applications, homepage shortcuts, etc.)

## Maintenance
- **Manual infra syncs** for infrastructure changes
- **Monitor Grafana** for system health
- **Regular security updates** for container images

## Configuration Management Strategy

### GitOps Principles
- All infrastructure and applications managed through Git
- Declarative configuration files
- Automated deployment through ArgoCD
- Version-controlled changes with proper commit messages

### Secrets Management
- Sensitive data stored as Kubernetes secrets
- Sealed secrets for Git-safe storage
- Proper RBAC and access controls

### Environment Management
- Multiple environments: dev, staging, uat, prod
- Environment-specific configurations
- Progressive deployment strategy

## Best Practices

### Infrastructure as Code
- Use Terraform for infrastructure provisioning
- Use Ansible for configuration management
- Maintain idempotent scripts and configurations

### Security
- Regular security audits
- Keep container images updated
- Implement proper network segmentation
- Use least privilege principles

### Monitoring & Logging
- Comprehensive metrics collection
- Centralized logging with Loki
- Alerting for critical issues
- Performance monitoring
