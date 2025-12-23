# Git Bisect Workflow

This workflow finds bug via bisect.

## Parameters
- good: Good commit. Required.
- bad: Bad commit. Required.

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Start: git bisect start {bad} {good}.
3. Test: Prompt good/bad.
4. Reset: On finish.
5. Log: Culprit commit.
