# Rebase Workflow

This workflow rebases branch.

## Parameters
- base: Base branch. Required.

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Pull base.
3. Rebase: git rebase {base}.
4. Resolve conflicts.
5. Confirm push.
6. Log: Rebase status.
