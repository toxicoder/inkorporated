# Containerize Workflow

This workflow dockerizes the app.

## Parameters
- image: Image name (default: project).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Generate Dockerfile.
3. Build: docker build.
4. Test: docker run.
5. Push: Prompt registry.
6. Log: Image ID.
