---
title: Backups
description: Backups for Inkorporated.
tags: [infrastructure]
---

# Backup & Disaster Recovery


**What's on this page**

- Documentation for this infrastructure topic.

**What this enables**


## Backup and restore path

```mermaid
flowchart LR
  cluster[Cluster state] --> velero[Velero]
  velero --> minio[MinIO / S3]
  minio --> restore[Restore target]
```

- Operators can deploy and operate Inkorporated systems confidently.

- **Velero**: Scheduled cluster backups to MinIO
- **Longhorn**: Recurring S3 exports
- **CNPG/MongoDB**: Continuous archiving
- **pfSense**: Config backup via package or manual export
- **Test restores**: Regular testing in dev namespace
