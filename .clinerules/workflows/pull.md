# Safe Pull Workflow

This workflow pulls changes safely.

## Parameters
- branch: Branch to pull (default: current).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Stash changes: If dirty.
3. Pull: git pull.
4. Apply stash: If stashed.
5. Log: Pull details.
