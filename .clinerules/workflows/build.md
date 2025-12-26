# Infrastructure Build Workflow

This workflow prepares and validates Inkorporated homelab infrastructure builds.

## Parameters
- target: Build target (e.g., prod, dev, staging). Default: dev.
- validate: Boolean to run validation checks (default: true).
- deploy: Boolean to trigger deployment (default: false).

## Steps
1. Validate inputs: Log to workflow_log.txt. Check target and parameters.
2. Environment Setup: Prepare environment variables and configuration files.
3. Manifest Generation: Generate Kubernetes manifests based on templates.
4. Configuration Validation: Run validate_config.sh and environment checks.
5. Security Validation: Verify file permissions and security settings.
6. Dry Run: Test deployment with kubectl apply --dry-run.
7. Artifact Verification: Check that all required manifests and configs are present.
8. Test Build: Run smoke tests on infrastructure components.
9. Confirm: Prompt if issues found in validation or build.
10. Log: Append build output with timestamps and status.
11. Deploy: If deploy=true, trigger deployment workflow.
12. On error: Clean up partial builds and log errors.

## Project-Specific Notes for Inkorporated
- Must integrate with the centralized configuration management system
- Should validate all manifests against the defined deployment patterns
- Must check Cloudflare Tunnel token configuration
- Should verify all services follow the correct deployment structure (namespace, deployment, service, ingress, etc.)
- Must validate the zero-trust security model setup
- Should test storage solutions (Longhorn, NFS CSI) configuration
- Must include validation for backup and monitoring stack
- Should verify network security with pfSense
- Must validate authentication flow with Authentik and Traefik