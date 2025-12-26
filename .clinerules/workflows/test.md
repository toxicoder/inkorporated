# Testing Workflow

This workflow manages infrastructure and configuration tests for Inkorporated homelab.

## Parameters
- action: run, add, coverage (default: run).
- target: Test suite or component to focus on (optional).
- env: Environment to test against (default: dev).

## Steps
1. Validate inputs: Log to workflow_log.txt. Check environment and test scope.
2. Setup: Ensure test framework is installed and environment variables are loaded.
3. Execute:
   - Run: Execute infrastructure tests, configuration validation, and security checks.
   - Add: Generate new tests for infrastructure components.
   - Coverage: Run with coverage tool for configuration validation scripts.
4. Infrastructure Tests: Run kubernetes manifest validation, RBAC checks, and service connectivity tests.
5. Configuration Tests: Run validate_config.sh and environment variable validation.
6. Security Tests: Execute security permission checks and vulnerability scans.
7. Integration Tests: Test service integrations (Authentik, Traefik, Cloudflared).
8. Analyze: If failures, suggest fixes and remediation steps.
9. Confirm fixes: If adding or fixing, prompt approval.
10. Commit: If changes, git commit -m "{action} tests".
11. Cleanup: Log results. Handle errors by pausing.
12. Report: Generate test summary report with pass/fail metrics.

## Project-Specific Notes for Inkorporated
- Must integrate with the existing validation script (validate_config.sh)
- Should validate all services against the deployment patterns defined in the architecture
- Must include tests for the centralized configuration management system
- Should verify the zero-trust security model with Cloudflare Tunnel and Authentik
- Must test storage solutions (Longhorn, NFS CSI) functionality
- Should validate backup and disaster recovery procedures
- Must include monitoring and observability stack validation
- Should test the multi-zone network architecture with pfSense
- Must validate all service integrations including authentication flow