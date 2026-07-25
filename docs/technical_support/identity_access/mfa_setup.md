---
title: MFA Setup
description: MFA Setup for Inkorporated.
tags: [enterprise]
---

## Multi-Factor Authentication (MFA) Setup

We use Duo Security for Multi-Factor Authentication to protect company assets.

### Enrollment

1.  Log in to the SSO portal. You will be prompted to enroll in MFA if you haven't already.
2.  Choose "Mobile Device" and enter your phone number.
3.  Download the **Duo Mobile** app from the App Store or Google Play Store.
4.  Scan the QR code displayed on your screen with the Duo app.

### Hardware Tokens (YubiKey)

For engineering roles or upon request, YubiKeys are available.

1.  Request a YubiKey via the [Accessory Request](../hardware/accessory_request.md) page.
2.  Once received, insert the key into your USB port.
3.  In the Duo prompt, select "Add a new device" -> "Security Key".
4.  Touch the YubiKey when prompted.

### Backup Codes

It is highly recommended to generate backup codes in case you lose your phone.

1.  Go to your MFA settings in the SSO portal.
2.  Select "Generate Backup Codes".
3.  Store these in a secure location (e.g., password manager, physical safe). Do not save them on your desktop.
