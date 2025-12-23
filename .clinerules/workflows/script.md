# Script Generation Workflow

This workflow generates utility scripts.

## Parameters
- purpose: e.g., backup, deploy. Required.

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Generate script code.
3. Save to scripts/.
4. Make executable.
5. Test.
6. Confirm.
7. Commit: "Add {purpose} script".
