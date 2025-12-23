# Add Feature Workflow

This workflow adds a new feature based on a description.

## Parameters
- description: Detailed feature spec (e.g., "Add user authentication with JWT"). Required.
- location: Directory or file to add to (optional; default: infer from description).

## Steps
1. Validate inputs: Check description length (>20 chars). Log to workflow_log.txt.
2. Plan implementation: Break description into subtasks (e.g., update models, add routes, write tests). Output plan.md.
3. Generate code: For each subtask, create or modify files with new code. Use temp directories for drafts.
4. Integrate: Merge drafts into main codebase. Handle conflicts by prompting.
5. Test: Write and run unit/integration tests for the feature. If fails, refine code.
6. Document: Update README.md or docs with feature usage.
7. Confirm: Show full diff. Prompt: "Commit feature? (yes/no)".
8. Commit: git add . && git commit -m "Feat: {description summary}".
9. Cleanup: Remove temps. Log outcomes.
10. On error: Revert, log, and suggest adjustments.
