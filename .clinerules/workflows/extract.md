# Extract Method Workflow

This workflow extracts code to method.

## Parameters
- file: File. Required.
- lines: Line range. Required.

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Extract: Create new func.
3. Replace: With call.
4. Test.
5. Confirm.
6. Commit: "Extract method".
