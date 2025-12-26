# CI Simulation Workflow

This workflow simulates the Inkorporated homelab CI pipeline locally.

## Parameters
- jobs: List of jobs (e.g., test,lint,validate,security). Default: all.
- env: Environment to test against (default: dev).

## Steps
1. Validate inputs: Log to workflow_log.txt. Check job list and environment.
2. Run jobs: Sequentially execute infrastructure validation, configuration tests, security checks, and deployment readiness checks.
3. Infrastructure Validation: Validate Kubernetes manifests and deployment patterns.
4. Configuration Validation: Run validate_config.sh and environment variable checks.
5. Security Checks: Execute security permission validation and vulnerability scans.
6. Integration Tests: Test service integrations and connectivity.
7. Report: Aggregate results in ci_report.md with detailed infrastructure status.
8. If fails: Pause for fixes and remediation steps.
9. Log: Full outputs with timestamps and status codes.
10. Notify: Send status notification if configured.

## Project-Specific Notes for Inkorporated
- Must integrate with the existing validation and testing workflows
- Should validate all services against the defined deployment patterns
- Must check the centralized configuration management system
- Should verify the zero-trust security model implementation
- Must validate storage solutions (Longhorn, NFS CSI) configuration
- Should test backup and disaster recovery procedures
- Must include monitoring stack validation
- Should verify network security with pfSense
- Must validate authentication flow with Authentik and Traefik