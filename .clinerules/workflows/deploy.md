# Deployment Workflow

This workflow deploys the Inkorporated homelab infrastructure using GitOps principles.

## Parameters
- env: Environment (e.g., dev, staging, prod). Required.
- dry_run: Boolean (default: false).
- namespace: Kubernetes namespace to deploy to (default: all).

## Steps
1. Validate inputs: Ensure env is valid and namespace is correct. Log to workflow_log.txt.
2. Config check: Verify deployment configs and environment variables.
3. GitOps Sync: Trigger ArgoCD sync for the specified environment.
4. K8s Validation: Check that all deployments are healthy and ready.
5. Service Verification: Verify core services (Authentik, Traefik, Cloudflared) are functioning.
6. Config Validation: Run configuration validation script (validate_config.sh).
7. Security Check: Verify proper RBAC and security policies are applied.
8. Monitor: Check for any deployment issues or errors in logs.
9. Confirm: Prompt: "Rollback on failure?".
10. Log: Full deploy logs with timestamp and status.
11. Cleanup: Handle rollbacks on error or failed deployments.
12. Notification: Send deployment status notification if configured.

## Project-Specific Notes for Inkorporated
- Must integrate with ArgoCD for GitOps deployment as specified in the architecture
- Should validate the centralized configuration management system during deployment
- Must verify Cloudflare Tunnel token is properly configured
- Should check that all services follow the deployment patterns (namespace, deployment, service, ingress, etc.)
- Must validate the zero-trust access setup with Traefik and Authentik
- Should verify storage solutions (Longhorn, NFS CSI) are properly deployed
- Must include validation for backup and monitoring stack deployment
- Should check for proper RBAC and network policies in deployed manifests