# Pull Request Workflow

This workflow creates a pull request.

## Parameters
- base: Base branch (default: main).
- title: PR title. Required.
- body: PR body (optional).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Push branch: git push origin HEAD.
3. Create PR: Use gh pr create or equivalent.
4. Add reviewers: Prompt for users.
5. Confirm: Display PR link.
6. Log: PR details.
7. On error: Delete remote branch if failed.
