---
title: Information Security Policy
description: Information Security Policy for Inkorporated.
tags: [enterprise, policy]
---

# Information Security Policy


**What's on this page**

- Core content for this topic in the Inkorporated enterprise OS.
- Practical guidance, roles, or standards as applicable.

**What this enables**

- Consistent enterprise operations and decision-making.
- Shared language for humans and cyborg AI agents.

## 1. Purpose
This policy outlines the measures to protect the Company's information assets from unauthorized access, use, disclosure, disruption, modification, or destruction. It establishes the framework for the Company's Information Security Management System (ISMS).

## 2. Access Control
*   **Principle of Least Privilege**: Access to systems and data is granted only to the extent necessary for individuals to perform their job functions.
*   **Authentication**: Strong passwords (minimum 12 characters, alphanumeric + symbols) and Multi-Factor Authentication (MFA) are required for all critical systems.
*   **Role-Based Access Control (RBAC)**: Access rights are grouped by role. Reviews of access rights are conducted quarterly.
*   **Offboarding**: Access for terminated employees or contractors must be revoked within 24 hours of their departure.

## 3. Network Security
*   **Firewalls**: All networks must be protected by firewalls to filter traffic based on defined rules.
*   **VPN**: Remote access to internal resources requires a secure Virtual Private Network (VPN) connection.
*   **Segmentation**: Critical systems must be segregated from general office networks.
*   **Wireless Security**: WPA2-Enterprise or higher encryption is required for all wireless networks. Guest networks must be isolated.

## 4. Device & Endpoint Security
*   **Encryption**: All laptops and mobile devices must use full-disk encryption (e.g., BitLocker, FileVault).
*   **Anti-Malware**: Up-to-date antivirus/anti-malware software must be installed and active on all endpoints.
*   **Patch Management**: Operating systems and applications must be patched within 30 days of critical security update releases.
*   **Physical Security**: Devices must not be left unattended in public areas and must be locked when not in use.

## 5. Application Security
*   **Secure Development Lifecycle (SDLC)**: Security reviews and testing (SAST/DAST) are integrated into the software development process.
*   **Code Review**: All code changes require peer review before deployment to production.
*   **Secrets Management**: Hardcoding credentials in source code is strictly prohibited. Use environment variables or secrets management services.

## 6. Vulnerability Management
*   **Regular Scans**: Automated vulnerability scans are performed weekly on all external and internal assets.
*   **Penetration Testing**: Third-party penetration tests are conducted annually.
*   **Remediation**: Critical vulnerabilities must be remediated within 48 hours; High within 1 week; Medium within 1 month.

## 7. Incident Response
*   **Reporting**: All employees are required to report suspected security incidents to `{{SECURITY_EMAIL}}` immediately.
*   **Process**:
    1.  **Preparation**: Training and tooling.
    2.  **Detection & Analysis**: Monitoring and triaging alerts.
    3.  **Containment**: Isolating affected systems to prevent spread.
    4.  **Eradication**: Removing the root cause (malware, bad actor).
    5.  **Recovery**: Restoring systems to normal operation.
    6.  **Post-Incident Activity**: Lessons learned and policy updates.

## 8. Physical Security
*   **Office Access**: Access to office premises is restricted to authorized personnel via badges or keys.
*   **Visitor Management**: Visitors must sign in, sign an NDA if necessary, and be escorted at all times.
*   **Clean Desk Policy**: Confidential documents must be secured in locked drawers when not in use.
