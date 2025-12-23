# Teardown Workflow

This workflow tears down resources.

## Parameters
- scope: env, db, all (default: all).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Confirm: Destructive action.
3. Teardown: rm env, drop db.
4. Log: Teardown items.
