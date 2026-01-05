# Plan Task Workflow

This workflow reviews the TODO.md file to identify completed and pending tasks, analyzes dependencies, and selects an initial task for execution.

## Parameters

- None

## Steps

1. Validate inputs: Log to workflow_log.txt.
2. Read TODO.md file: Use read_file tool to examine the task list.
3. Identify completed tasks: Scan for tasks marked 'Completed: Yes'.
4. Identify pending tasks: Find tasks that are not yet completed.
5. Analyze dependencies: Review task dependencies to understand relationships.
6. Select initial task: Choose a foundational task with no unresolved dependencies.
7. Outline strategy: Create detailed step-by-step strategy including actions, resources, challenges, and rationale.
8. Present for approval: Show selected task and strategy to user for approval.
9. Ask clarifying questions: If any information in TODO.md is unclear or conflicting, ask user for clarification.
10. Move to Act Mode: Proceed with implementation after user approval.

## Project-Specific Notes for Inkorporated

- This workflow is specifically designed for the Inkorporated homelab infrastructure project
- Must integrate with the centralized configuration management system
- Should validate all tasks against the defined deployment patterns
- Must follow the multi-phase implementation approach (Phase 1 tasks are foundational)
- Should consider the zero-trust security model when selecting tasks
- Must validate storage solutions (Longhorn, NFS CSI) configuration in task selection
- Should verify backup and disaster recovery procedures in task dependencies
- Must include monitoring and observability stack validation in task planning
- Should verify network security with pfSense in task dependencies
- Must validate authentication flow with Authentik and Traefik when planning tasks
