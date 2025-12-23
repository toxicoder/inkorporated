# Add Comments Workflow

This workflow adds comments to code.

## Parameters
- file: File to comment. Required.

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Analyze code.
3. Generate comments.
4. Insert: Diff and confirm.
5. Commit: "Add comments".
