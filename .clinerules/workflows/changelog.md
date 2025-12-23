# Changelog Generation Workflow

This workflow generates changelog.

## Parameters
- since: From tag or date (optional).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Fetch commits: git log.
3. Format: Categorize.
4. Update CHANGELOG.md.
5. Confirm: Show diff.
6. Commit: "Update changelog".
