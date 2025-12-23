# Merge Workflow

This workflow merges branches safely.

## Parameters
- source: Branch to merge from. Required.
- target: Branch to merge into (default: main).

## Steps
1. Validate inputs: Check branches exist. Log to workflow_log.txt.
2. Pull latest: git pull for both.
3. Merge: git checkout {target} && git merge {source}.
4. Resolve conflicts: If any, pause and prompt manual fix.
5. Test: Run tests post-merge.
6. Confirm: Prompt push.
7. Push: git push.
8. On error: Abort merge.
