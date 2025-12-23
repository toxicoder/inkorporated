# Linting Workflow

This workflow runs code linters.

## Parameters
- scope: Files or dirs (default: all).
- fix: Boolean to auto-fix (default: false).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Detect linter: Based on lang (e.g., eslint, pylint).
3. Run lint: Execute with --fix if fix=true.
4. Report: Save issues to lint_report.md.
5. Confirm fixes: If changes, show diff and prompt.
6. Commit: If fixed, git commit -m "Lint fixes".
7. On error: Log failures.
