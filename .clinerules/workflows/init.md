# Project Initialization Workflow

This workflow sets up a new project structure.

## Parameters
- name: Project name. Required.
- lang: Programming language (e.g., python, js). Default: python.
- template: Boilerplate type (e.g., web, cli). Optional.

## Steps
1. Validate inputs: Ensure name is alphanumeric. Log to workflow_log.txt.
2. Create directory: mkdir {name} && cd {name}.
3. Initialize repo: git init.
4. Add files: Based on lang and template, create main file (e.g., main.py), README.md, .gitignore.
5. Install deps: Run init command (e.g., npm init -y, poetry init).
6. Confirm: Display structure. Prompt: "Proceed? (yes/no)".
7. Commit: git add . && git commit -m "Initial commit".
8. Cleanup: Log setup. Revert on error.
