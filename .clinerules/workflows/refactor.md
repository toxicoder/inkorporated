# Refactor Workflow

This workflow refactors code for better structure.

## Parameters
- target: File or directory to refactor. Required.
- goal: e.g., "improve performance" or "clean up" (default: clean up).

## Steps
1. Validate inputs: Check target exists. Log to workflow_log.txt.
2. Backup: Git commit "Backup before refactor {target}".
3. Analyze: Scan for smells (duplication, long methods).
4. Suggest changes: Generate refactored code in temp file.
5. Apply: Patch original, run tests to validate.
6. Confirm: Show diff. Prompt: "Apply? (yes/no)".
7. Commit: git commit -m "Refactor: {goal} in {target}".
8. Cleanup: Revert on error, log details.
