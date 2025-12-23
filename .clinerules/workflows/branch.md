# Branch Creation Workflow

This workflow creates a new branch.

## Parameters
- name: Branch name. Required.
- from: Base branch (default: main).

## Steps
1. Validate inputs: Ensure name is valid. Log to workflow_log.txt.
2. Pull base: git pull {from}.
3. Create: git checkout -b {name}.
4. Confirm: Prompt: "Switch to new branch?".
5. Log: Branch details.
