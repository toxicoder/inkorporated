---
title: Wi-Fi Access
description: Wi-Fi Access for Inkorporated.
tags: [enterprise]
---

## Office Wi-Fi Networks

We have two primary Wi-Fi networks in all office locations.

### Employee Network: `Office-Secure`

This is the primary network for company-issued devices.

*   **SSID**: `Office-Secure`
*   **Authentication**: WPA2-Enterprise (802.1x) with Certificate.
*   **How to Connect**:
    *   Your laptop should automatically connect via the pushed MDM profile.
    *   If prompted, select your user certificate.
*   **Access**: Full access to internal resources, printers, and the internet.

### Guest Network: `Office-Guest`

This network is for personal devices and visitors.

*   **SSID**: `Office-Guest`
*   **Password**: Rotates monthly. Check the digital signage in the lobby or ask the receptionist. Currently: `GuestAccess2024!`
*   **Access**: Internet only. No access to internal resources.

### Troubleshooting Connection Issues

1.  **"Unable to join network"**: Forget the network and try re-joining.
2.  **Weak Signal**: Move closer to an access point (look for the white circular devices on the ceiling).
3.  **Certificate Error**: If prompted to trust a certificate named `radius.company.com`, click **Trust**.
