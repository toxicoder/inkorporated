# API Testing Workflow

This workflow tests APIs.

## Parameters
- endpoint: API endpoint. Required.
- method: GET, POST, etc. Default: GET.

## Steps
1. Validate inputs: Log to workflow_log.txt.
2. Prepare request: Add headers, body.
3. Send: Use curl or requests.
4. Check response: Status, content.
5. Report: api_test_report.md.
6. On error: Log response.
