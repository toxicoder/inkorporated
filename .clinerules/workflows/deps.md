# Dependency Management Workflow

This workflow updates and checks project dependencies.

## Parameters
- action: update, check_vulns, or clean (default: update).
- force: Boolean to force updates (default: false).

## Steps
1. Validate inputs: Log parameters to workflow_log.txt.
2. Detect manager: Identify tool (npm, pip, cargo, etc.) based on lock files.
3. Backup: Commit current deps with "Backup deps before {action}".
4. Perform action:
   - Update: Run update command (e.g., npm update). If force=false, only non-breaking.
   - Check_vulns: Use safety tools (e.g., npm audit, pip check) and report issues.
   - Clean: Remove unused deps (e.g., depcheck for JS).
5. Test after: Run full test suite. If fails, revert.
6. Confirm: Display changes. Prompt: "Apply? (yes/no)".
7. Commit: git commit -m "{action} dependencies".
8. Cleanup: Revert on error, log details.
