# Testing Workflow

This workflow manages tests: run, add, or coverage.

## Parameters
- action: run, add, coverage (default: run).
- target: File or suite to focus on (optional).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Setup: Ensure test framework is installed.
3. Execute:
   - Run: Execute tests, capture output.
   - Add: Based on code, generate new tests (e.g., for uncovered functions).
   - Coverage: Run with coverage tool, report percentages.
4. Analyze: If failures, suggest fixes.
5. Confirm fixes: If adding or fixing, prompt approval.
6. Commit: If changes, git commit -m "{action} tests".
7. Cleanup: Log results. Handle errors by pausing.
