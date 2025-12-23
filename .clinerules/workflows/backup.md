# Backup Workflow

This workflow backs up the project.

## Parameters
- dest: Backup destination (default: backups/).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Create archive: git archive or zip.
3. Store: To dest.
4. Verify: Check integrity.
5. Log: Backup path.
