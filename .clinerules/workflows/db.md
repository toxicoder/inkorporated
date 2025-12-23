# Database Workflow

This workflow handles DB operations.

## Parameters
- action: migrate, seed, backup (default: migrate).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Check connection: Test DB access.
3. Run action: e.g., alembic upgrade, pg_dump.
4. Verify: Check DB state.
5. Confirm: For destructive actions.
6. Backup if needed.
7. Log: Operation logs.
