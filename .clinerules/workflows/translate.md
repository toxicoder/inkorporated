# Translation Workflow

This workflow translates code/comments.

## Parameters
- lang: Target language. Required.
- scope: comments, code (default: comments).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Identify text.
3. Translate: Manual or tool.
4. Apply: Diff and confirm.
5. Commit: "Translation to {lang}".
