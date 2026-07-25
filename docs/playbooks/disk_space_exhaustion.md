---
title: Disk Space Exhaustion
description: Disk Space Exhaustion for Inkorporated.
tags: [enterprise]
---

**Scenario:** Server or container volume is running out of disk space.

## 1. Symptoms
* Alert: "Disk Usage > 90%".
* Application failing to write logs or temp files.
* Error: `No space left on device`.

## 2. Severity Assessment
* **SEV 1:** Root partition full. System unbootable or services crashing.
* **SEV 2:** Data partition full. Cannot write new data.
* **SEV 3:** Warning threshold reached (> 80%).

## 3. Initial Verification
* **Command:** Run `df -h` to check usage.
* **Identify:** Which partition is full? (`/`, `/var`, `/tmp`, `/data`).

## 4. Investigation
* **Find Big Files:** Run `du -sh * | sort -rh | head -n 10` in the suspected directory.
* **Open Files:** Check for deleted files held open by processes (`lsof | grep deleted`).

## 5. Mitigation
* **Clean Logs:** Truncate large log files (don't delete if open): `> /var/log/app.log`.
* **Delete Temp:** `rm -rf /tmp/*`.
* **Prune Docker:** `docker system prune -a` (careful!).
* **Expand Volume:** Increase EBS volume size or PVC size dynamically.

## 6. Resolution
* Configure log rotation (`logrotate`).
* Move temp files to a dedicated volume.
* Implement automatic retention policies.

## 7. Escalation
* **Infrastructure Team**.
