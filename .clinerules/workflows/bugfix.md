# Bug Fix Workflow

This workflow identifies and attempts to fix a described bug.

## Parameters
- description: Text description of the bug (e.g., "App crashes on login"). Required.
- file: Suspected file path (optional).

## Steps
1. Validate inputs: Ensure description is provided. Log to workflow_log.txt.
2. Reproduce bug: Prompt for reproduction steps if not in description. Run relevant tests or commands to confirm (e.g., simulate error).
3. Analyze codebase: Search files for related code (grep or AST parsing if language supports). If file provided, focus there.
4. Generate fix: Propose code changes based on description. Create a patch file (bugfix.patch) with before/after code.
5. Test fix: Apply patch temporarily, run tests. If fails, iterate: Suggest alternative fixes and prompt selection.
6. Confirm: Display patch diff. Prompt: "Apply fix? (yes/no)".
7. Apply and commit: If yes, apply patch, git add, git commit -m "Fix: {description summary}".
8. Cleanup: Remove patch file. Log full process.
9. On error: Revert changes, log details, suggest manual debugging.
