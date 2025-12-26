# Infrastructure Audit Workflow

This workflow audits Inkorporated homelab infrastructure and security posture.

## Parameters
- metrics: security, compliance, performance, manifest (default: all).
- env: Environment to audit (default: dev).

## Steps
1. Validate inputs: Log to workflow_log.txt. Check metrics and environment.
2. Run tools: Security scanners, compliance checks, performance analysis.
3. Security Audit: Check for vulnerabilities in configurations and manifests.
4. Compliance Audit: Verify adherence to deployment patterns and security policies.
5. Performance Audit: Analyze resource utilization and efficiency.
6. Manifest Audit: Review Kubernetes manifest best practices and patterns.
7. Report: Generate audit_report.md with detailed findings.
8. Suggest improvements: Provide remediation recommendations.
9. Log: Audit results with timestamps and severity levels.
10. Notify: Send audit summary notification if configured.

## Project-Specific Notes for Inkorporated
- This workflow aligns with the security approach using MCP-based scanning tools
- Should integrate with the centralized configuration management system
- Must validate the zero-trust architecture with Cloudflare Tunnel and Authentik
- Should check for proper RBAC and network policies in Kubernetes manifests
- Must verify storage solutions (Longhorn, NFS CSI) are properly configured
- Should validate backup and disaster recovery setup with Velero
- Must include checks for the multi-zone network architecture with pfSense