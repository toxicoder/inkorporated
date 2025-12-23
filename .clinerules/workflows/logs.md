# View Logs Workflow

This workflow views logs.

## Parameters
- source: app, git, system (default: app).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Fetch: tail -f or git log.
3. Filter: Prompt keywords.
4. Output: To console.
