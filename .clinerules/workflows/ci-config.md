# CI Config Generation Workflow

This workflow generates CI config.

## Parameters
- provider: github, gitlab (default: github).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Generate: .github/workflows.
3. Add jobs: test, deploy.
4. Confirm: Add to repo.
5. Commit: "Add CI config".
