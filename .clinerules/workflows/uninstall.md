# Uninstall Dependencies Workflow

This workflow uninstalls deps.

## Parameters
- package: Name to uninstall. Required.

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Run uninstall: npm uninstall, pip uninstall.
3. Clean: Remove orphans.
4. Confirm: Prompt before.
5. Log: Uninstalled.
