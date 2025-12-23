# Squash Commits Workflow

This workflow squashes commits.

## Parameters
- count: Number to squash (default: 2).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Rebase interactive: git rebase -i HEAD~{count}.
3. Prompt message.
4. Log: Squashed.
