# Infrastructure Setup Workflow

This workflow sets up the Inkorporated homelab infrastructure locally.

## Parameters
- env: Environment to setup (e.g., dev, staging, prod). Default: dev.
- full: Boolean to perform full setup (default: false).
- validate: Boolean to run validation after setup (default: true).

## Steps
1. Validate inputs: Log to workflow_log.txt. Check environment and parameters.
2. Clone if needed: Clone repository if not local.
3. Environment Setup: Create and configure environment-specific config files.
4. Dependency Check: Verify required tools (kubectl, k3s, helm, etc.) are installed.
5. Configuration Validation: Run validate_config.sh to check setup.
6. Security Setup: Set proper file permissions for config files.
7. Test Connectivity: Verify connectivity to k3s cluster and services.
8. Initialize: Create required namespaces and directories.
9. Validate: Run infrastructure validation checks.
10. Log: Setup complete with status and next steps.
11. Notify: Send setup completion notification if configured.