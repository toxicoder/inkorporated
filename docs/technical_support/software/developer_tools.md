---
title: Developer Tools
description: Developer Tools for Inkorporated.
tags: [enterprise]
---

## Developer Tools & Ecosystem

We provide a robust suite of tools for engineering teams.

### IDE Licensing

We maintain an enterprise license server for JetBrains products.

*   **URL**: `https://jetbrains.company.com`
*   **Supported IDEs**: IntelliJ IDEA, PyCharm, GoLand, WebStorm, CLion, DataGrip.
*   **Activation**:
    1.  Open the IDE.
    2.  Select **License Server**.
    3.  Enter the URL above.
    4.  Click **Activate**.

### Package Mirrors

To ensure build stability and security, use our internal mirrors.

#### Python (PyPI)
Configure `~/.pip/pip.conf`:
```ini
[global]
index-url = https://artifactory.company.com/artifactory/api/pypi/pypi/simple
trusted-host = artifactory.company.com
```

#### Node.js (NPM)
Configure `~/.npmrc`:
```bash
registry=https://artifactory.company.com/artifactory/api/npm/npm/
```

#### Docker Registry
*   **Public Hub Mirror**: `docker-mirror.company.com`
*   **Internal Registry**: `registry.company.com`
*   **Login**: `docker login registry.company.com` (Use your AD credentials).

### Source Control

*   **GitHub Enterprise**: `https://github.company.com`
*   **Access**: SSO enabled.
*   **SSH Keys**: Must be Ed25519. RSA keys < 4096 bits are rejected.
