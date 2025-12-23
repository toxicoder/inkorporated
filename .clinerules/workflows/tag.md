# Tag Management Workflow

This workflow manages git tags.

## Parameters
- action: create, delete, list (default: list).
- name: Tag name (for create/delete).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Execute: git tag.
3. Push: If create, prompt push.
4. Log: Tag operations.
