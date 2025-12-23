# Unstash Workflow

This workflow applies stash.

## Parameters
- index: Stash index (default: 0).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Apply: git stash apply.
3. Drop: Prompt drop after.
4. Log: Applied stash.
