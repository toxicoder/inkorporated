# Commit Message Workflow

This workflow generates and applies commit messages.

## Parameters
- type: feat, fix, chore, etc. (optional; infer if not).

## Steps
1. Get changes: git diff --cached.
2. Generate message: Use conventional commits format, summarize changes.
3. Prompt: Display suggested message. "Use this? Edit or abort."
4. Commit: git commit -m "{message}".
5. Log: Append to workflow_log.txt.
6. On error: No commit, suggest manual.
