# Code Audit Workflow

This workflow audits code quality.

## Parameters
- metrics: loc, complexity (default: all).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Run tools: radon, cloc.
3. Report: audit_report.md.
4. Suggest improvements.
5. Log: Audit results.
