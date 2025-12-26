# Infrastructure Dependencies Workflow

This workflow manages infrastructure dependencies for Inkorporated homelab.

## Parameters
- type: Dependency type (k8s, tools, helm, ansible). Default: all.
- env: Environment to install for (default: dev).
- upgrade: Boolean to upgrade existing dependencies (default: false).

## Steps
1. Validate inputs: Log to workflow_log.txt. Check dependency type and environment.
2. Tool Check: Verify required infrastructure tools are installed (kubectl, helm, k3s, etc.).
3. Package Management: Install/upgrade infrastructure packages and tools.
4. Configuration: Set up tool configurations and environment variables.
5. Validation: Verify dependencies are properly installed and accessible.
6. Security: Apply proper permissions and security settings to installed tools.
7. Log: Installed dependencies with versions and locations.
8. Test: Run basic connectivity tests for installed tools.
9. Notify: Send installation completion notification.