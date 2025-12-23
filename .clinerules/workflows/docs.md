# Documentation Generation Workflow

This workflow updates or generates project documentation.

## Parameters
- scope: all, readme, api (default: all).
- format: md, html (default: md).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Scan codebase: Identify functions, classes, etc., for docstrings.
3. Generate content: 
   - README: Add sections like installation, usage based on code.
   - API: Use tools like pydoc or jsdoc to extract.
4. Update files: Append or replace in docs/ or README.md.
5. Preview: Output changes to console.
6. Confirm: Prompt: "Apply updates? (yes/no)".
7. Commit: git commit -m "Update docs: {scope}".
8. Cleanup: Log full process. Revert on error.
