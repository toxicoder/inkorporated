# Infrastructure Feature Workflow

This workflow adds new infrastructure components or services to Inkorporated homelab.

## Parameters
- description: Detailed feature spec (e.g., "Add new monitoring service with Prometheus"). Required.
- location: Directory or file to add to (optional; default: infer from description).
- env: Environment to implement feature in (default: dev).

## Steps
1. Validate inputs: Check description length (>20 chars). Log to workflow_log.txt.
2. Plan implementation: Break description into subtasks (e.g., create namespace, deployment, service, ingress). Output plan.md.
3. Generate manifests: Create Kubernetes manifests (Deployment, Service, Ingress, ConfigMap, etc.) for new components.
4. Configuration: Generate and validate configuration files and environment variables.
5. Security: Apply proper RBAC, network policies, and security settings.
6. Integrate: Merge new manifests into appropriate directories. Handle conflicts by prompting.
7. Test: Validate new manifests with kubectl apply --dry-run and run integration tests.
8. Document: Update documentation with new service details and configuration requirements.
9. Validate: Run configuration validation and security checks.
10. Confirm: Show full diff. Prompt: "Commit feature? (yes/no)".
11. Commit: git add . && git commit -m "Feat: {description summary}".
12. Cleanup: Remove temp files. Log outcomes.
13. Notify: Send feature implementation notification if configured.
14. On error: Revert, log, and suggest adjustments.

## Project-Specific Notes for Inkorporated
- Must follow the defined deployment patterns (namespace, deployment, service, ingress, etc.)
- Should integrate with the centralized configuration management system
- Must validate the zero-trust security model implementation for new features
- Should verify storage solutions (Longhorn, NFS CSI) integration
- Must validate backup and disaster recovery procedures for new components
- Should include monitoring and logging requirements for new services
- Must follow the multi-zone network architecture with pfSense firewall
- Should validate authentication flow with Authentik and Traefik for new services
- Must use the proper namespace organization as specified in the architecture