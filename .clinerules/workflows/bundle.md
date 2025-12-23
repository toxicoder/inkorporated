# Bundle Workflow

This workflow bundles assets.

## Parameters
- type: js, css (required).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Run bundler: webpack, etc.
3. Minify.
4. Verify.
5. Log: Bundle size.
