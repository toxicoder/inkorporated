# Post-Fork Workflow

This workflow handles all necessary tasks after forking a project, including updating links, crediting the original project, and ensuring proper attribution.

## Parameters
- original_repo_url: URL of the original repository. Required.
- new_repo_name: Name of the new forked repository. Required.
- new_repo_owner: Owner/organization of the new forked repository. Required.
- update_links: Boolean to update all internal links (default: true).
- add_credit: Boolean to add credit to original project (default: true).
- dry_run: Boolean flag to simulate without making changes (default: false).

## Steps
1. Validate inputs: Check that all required parameters are provided.
2. Create backup: Create a backup of current files before making changes.
3. Update README.md:
   - Add fork notice at the top
   - Update links to point to new repository
   - Add credit section with original project information
   - Update any repository-specific links
4. Update documentation files:
   - Update all markdown files with new repository links
   - Add fork attribution to documentation
5. Update configuration files:
   - Update any CI/CD configuration files with new repository paths
   - Update workflow files with new repository references
6. Update project metadata:
   - Update package.json, pyproject.toml, or other manifest files
   - Update any project-specific configuration files
7. Add fork notice to memory bank:
   - Update memory-bank/progress.md to indicate this is a fork
   - Add credit information to memory-bank/activeContext.md
8. Update Cline rules:
   - Update .clinerules/01-general.md with fork-specific guidelines
   - Update .clinerules/project-specific.md with fork information
9. Add credit section to technical documentation:
   - Add attribution to docs/technical_design_doc.md
   - Update any project overview sections
10. Confirm changes: Display a summary of all changes made. Prompt: "Proceed with post-fork setup? (yes/no)".
11. Git integration: git add . && git commit -m "Post-fork setup: Updated links and credited original project {original_repo_url}".
12. Log outcomes: Append full process to workflow_log.txt.
13. On error: Restore from backup if failed, log details, and suggest manual setup.
14. Cleanup: Ensure all temporary files are removed and directory is clean.
