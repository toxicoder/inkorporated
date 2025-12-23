# Release Workflow

This workflow automates preparing and publishing a new release for a library or application.

## Parameters
- version: The new version number (e.g., 1.0.1). Required.
- dry_run: Boolean flag to simulate without applying changes (default: false).

## Steps
1. Validate inputs: Check if 'version' is provided and follows semantic versioning format (e.g., MAJOR.MINOR.PATCH). If invalid, prompt for correction and log error to workflow_log.txt.
2. Backup current state: Create a temporary Git branch named 'release-backup-{version}' and commit all changes with message "Backup before release {version}".
3. Update version: Open package.json (or equivalent like pyproject.toml for Python, Cargo.toml for Rust) and replace the version field with the new {version}. If dry_run=true, log the proposed change instead.
4. Run tests: Execute the project's test suite (e.g., npm test, pytest, cargo test). If tests fail, log output to workflow_log.txt, revert to backup branch, and pause for user input: "Tests failed. Retry, fix manually, or abort?"
5. Generate changelog: Use git log --since=last-tag to fetch commits. Format them into CHANGELOG.md under a new section "## {version} - {current_date}". Categorize by type (feat, fix, chore) if commit messages follow conventional commits. If dry_run=true, output to console only.
6. Confirm changes: Display diff of modified files (package.json, CHANGELOG.md). Prompt: "Approve changes? (yes/no)"
7. Commit changes: If approved, run git add . && git commit -m "Release {version}".
8. Tag release: Run git tag v{version}.
9. Push to remote: Prompt: "Push to origin main and tags? (yes/no)". If yes, run git push origin main --tags.
10. Cleanup: Delete the backup branch if successful. Append full log to workflow_log.txt.
11. On error: At any failure, revert to backup, log details, and notify: "Workflow failed at step X. Review workflow_log.txt."
