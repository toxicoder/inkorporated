---
title: SSO Troubleshooting
description: SSO Troubleshooting for Inkorporated.
tags: [enterprise]
---

## Single Sign-On (SSO) Troubleshooting

We use Okta for Single Sign-On to access most internal applications (Slack, Jira, GitHub, etc.).

### Common Issues

#### "400 Bad Request" or Loop
*   **Cause**: Corrupted browser cookies or cache.
*   **Fix**:
    1.  Clear your browser cache and cookies for `*.company.com` and `*.okta.com`.
    2.  Restart your browser.
    3.  Try logging in again.

#### "Access Denied"
*   **Cause**: You may not have the required group membership for the application.
*   **Fix**:
    1.  Check if your teammates have access.
    2.  Request access via the [Software Request](../software/software_request.md) process (Access Request in Jira).
    3.  Include the specific error message and app name.

#### "MFA Prompt Not Appearing"
*   **Cause**: Ad blockers or browser extensions.
*   **Fix**:
    1.  Disable ad blockers for the SSO page.
    2.  Try using Incognito/Private mode.

### verifying Browser Compatibility

Ensure you are using the latest version of Chrome, Firefox, or Safari. Internet Explorer is not supported.
