# Build Workflow

This workflow builds the project artifacts.

## Parameters
- target: Build target (e.g., prod, dev). Default: prod.
- clean: Boolean to clean before build (default: true).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Clean: If clean=true, remove build dirs.
3. Run build: Execute build command (e.g., npm build, make).
4. Check artifacts: Verify output files exist.
5. Test build: Run smoke tests on artifacts.
6. Confirm: Prompt if issues found.
7. Log: Append build output.
8. On error: Clean up partial builds.
