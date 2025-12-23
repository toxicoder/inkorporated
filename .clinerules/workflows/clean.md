# Clean Workflow

This workflow cleans artifacts.

## Parameters
- scope: build, cache, all (default: all).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Identify files: e.g., __pycache__, node_modules.
3. Confirm delete: Show list.
4. Delete: rm -rf.
5. Log: Cleaned items.
