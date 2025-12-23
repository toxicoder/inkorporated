# memory-init.md

This workflow initializes the memory bank structure, creating the required directory and core files if they don't exist, based on standard project documentation practices.

## Parameters
- project_name: The name of the project. Required.
- dir: The directory for the memory bank (default: memory-bank).
- dry_run: Boolean flag to simulate without creating files (default: false).

## Steps
1. Validate inputs: Ensure project_name is provided and alphanumeric. Log parameters to workflow_log.txt.
2. Create directory: If not exists, mkdir {dir}. If dry_run=true, log the action instead.
3. Initialize core files: For each required file (projectbrief.md, productContext.md, activeContext.md, systemPatterns.md, techContext.md, progress.md):
   - Check if exists in {dir}/.
   - If not, create with basic template:
     - projectbrief.md: Headers for "Project Overview", "Core Requirements", "Goals".
     - productContext.md: Headers for "Purpose", "Problems Solved", "User Experience".
     - activeContext.md: Headers for "Current Focus", "Recent Changes", "Next Steps", "Insights".
     - systemPatterns.md: Headers for "Architecture", "Design Patterns", "Component Relationships".
     - techContext.md: Headers for "Technologies", "Setup", "Dependencies", "Constraints".
     - progress.md: Headers for "Current Status", "Completed Features", "Todo", "Issues".
   - If dry_run=true, output proposed content to console.
4. Prompt for initial content: For projectbrief.md, prompt user: "Provide brief project description?" and append if provided.
5. Confirm creation: Display list of created/checked files. Prompt: "Proceed with initialization? (yes/no)".
6. Git integration: If in a git repo, git add {dir}/* && git commit -m "Initialize memory bank for {project_name}".
7. Log outcomes: Append full process to workflow_log.txt, including any user inputs.
8. On error: Remove partially created files if failed, log details, and suggest manual setup.
9. Cleanup: No temps to remove, but ensure directory is clean.
