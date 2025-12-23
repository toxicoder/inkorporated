# Add License Workflow

This workflow adds a license.

## Parameters
- type: MIT, GPL, etc. Required.

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Fetch template.
3. Add LICENSE file.
4. Update README.
5. Confirm.
6. Commit: "Add {type} license".
