# Container Image Workflow

This workflow manages container images for Inkorporated homelab services.

## Parameters
- service: Service name to containerize (e.g., authentik, traefik). Required.
- tag: Image tag (default: latest).
- push: Boolean to push to registry (default: false).

## Steps
1. Validate inputs: Log to workflow_log.txt. Check service and parameters.
2. Service Detection: Identify service and its container requirements.
3. Generate Dockerfile: Create Dockerfile based on service requirements.
4. Build: docker build with appropriate context and tags.
5. Test: Run container with basic health checks.
6. Security Scan: Scan image for vulnerabilities.
7. Push: If push=true, push to container registry.
8. Log: Image ID and registry location.
9. Validate: Verify image can run in Kubernetes environment.
10. Notify: Send containerization completion notification.