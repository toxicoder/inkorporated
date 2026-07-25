---
title: VPN Configuration
description: VPN Configuration for Inkorporated.
tags: [enterprise]
---

## VPN Configuration

The Virtual Private Network (VPN) allows you to access internal resources securely when working remotely.

### VPN Client

We use **Cisco AnyConnect Secure Mobility Client**.

### Installation

1.  **Mac**: The client is pre-installed via MDM. Look for the Cisco AnyConnect icon in your Applications folder.
2.  **Windows**: Pre-installed via Intune.
3.  **Linux**:
    *   `sudo apt-get install network-manager-openconnect` (or equivalent).
    *   Or download the installer from the portal.

### Connecting

1.  Launch Cisco AnyConnect.
2.  Enter the server address: `vpn.company.com`.
3.  Click **Connect**.
4.  Enter your username and password.
5.  Approve the Duo MFA push.

### Split Tunneling

Our VPN uses split tunneling.
*   **Internal Traffic** (e.g., Jira, Intranet, internal servers) goes through the VPN.
*   **Internet Traffic** (e.g., Google, YouTube) goes directly to the internet. This improves performance.

### Troubleshooting

*   **Connection Failed**: Ensure you have a stable internet connection.
*   **MFA Timeout**: Approve the Duo push promptly.
*   **Certificate Error**: Re-install the root certificate from the [Security Portal](https://security.company.com).
