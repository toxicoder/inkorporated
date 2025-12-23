# Rename Refactor Workflow

This workflow renames variables/functions.

## Parameters
- old: Old name. Required.
- new: New name. Required.

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Find/replace: Across files.
3. Test: Run tests.
4. Confirm: Apply.
5. Commit: "Rename {old} to {new}".
