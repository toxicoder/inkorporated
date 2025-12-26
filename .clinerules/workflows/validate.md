# Validation Workflow

This workflow validates Inkorporated homelab infrastructure and configuration.

## Parameters
- target: File or schema to validate (e.g., config, manifests, security). Required.
- env: Environment to validate against (default: dev).

## Steps
1. Validate inputs: Log to workflow_log.txt. Check target and environment.
2. Configuration Validation: Run validate_config.sh and check environment variables.
3. Manifest Validation: Validate Kubernetes manifests using kubectl apply --dry-run.
4. Security Validation: Check file permissions, RBAC settings, and security configurations.
5. Integration Validation: Verify service integrations and connectivity.
6. Compliance Validation: Check adherence to deployment patterns and security policies.
7. Report issues: Generate detailed validation report with severity levels.
8. Fix if possible: Auto-fix simple configuration issues where safe.
9. Confirm: Prompt for manual review of critical issues.
10. Log: Validation status with timestamp and results.
11. Notify: Send validation results notification if configured.

## Project-Specific Notes for Inkorporated
- Must integrate with the existing validate_config.sh script
- Should validate all Kubernetes manifests against the defined deployment patterns
- Must check the centralized configuration management system for proper setup
- Should verify the zero-trust security model implementation
- Must validate storage configurations (Longhorn, NFS CSI)
- Should check backup and disaster recovery setup
- Must validate monitoring and observability stack
- Should verify network security with pfSense firewall
- Must validate authentication flow with Authentik and Traefik