# Code Review Workflow

This workflow performs an automated code review on recent changes or a specified file.

## Parameters
- file: Path to a specific file to review (optional; default: all staged changes).
- depth: Level of detail (shallow, medium, deep). Default: medium.

## Steps
1. Validate inputs: If file provided, check existence. Log parameters to workflow_log.txt.
2. Fetch changes: If no file, use git diff --cached or git diff HEAD to get recent changes. Save diff to temp_review.diff.
3. Analyze code: Break diff into hunks. For each:
   - Check for common issues: unused variables, inefficient loops, security vulnerabilities (e.g., hardcoded secrets).
   - Suggest improvements: Refactor suggestions, style fixes (e.g., based on PEP8 for Python, ESLint for JS).
   - Depth handling: Shallow=quick scan; medium=include examples; deep=simulate fixes in a temp file.
4. Generate report: Compile findings into a markdown report (review_report.md) with sections: Issues, Suggestions, Overall Score (e.g., 8/10).
5. Confirm application: If deep mode and fixes suggested, prompt: "Apply suggested fixes? (yes/no)". If yes, apply patches via git apply or manual edits.
6. Log and cleanup: Append report to workflow_log.txt. Remove temp files unless error occurs.
7. On error: Log stack trace or command output, prompt for retry.
