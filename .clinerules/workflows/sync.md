# Sync Workflow

This workflow syncs with remote.

## Parameters
- direction: push, pull (default: both).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Run rsync or git.
3. Confirm conflicts.
4. Log: Synced files.
