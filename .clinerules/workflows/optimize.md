# Optimization Workflow

This workflow optimizes code.

## Parameters
- target: Code section. Required.
- metric: speed, memory (default: speed).

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Profile first.
3. Suggest opts.
4. Apply: Prompt.
5. Test: Verify.
6. Commit: "Optimizations".
