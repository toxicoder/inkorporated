# Formatting Workflow

This workflow formats code style.

## Parameters
- scope: Files or dirs (default: all).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Detect formatter: e.g., black for Python, prettier for JS.
3. Run format: Apply formatting.
4. Check diff: Display changes.
5. Confirm: Prompt: "Apply? (yes/no)".
6. Commit: git commit -m "Code formatting".
7. Cleanup: Revert if not applied.
