# Restore Workflow

This workflow restores from backup.

## Parameters
- source: Backup file. Required.

## Steps
1. Validate inputs: Check source exists. Log to workflow_log.txt.
2. Extract: Unzip or git apply.
3. Verify: Run tests.
4. Confirm: Overwrite current?
5. Log: Restore details.
