---
title: Operational Playbooks
description: Operational Playbooks for Inkorporated.
tags: [enterprise]
---

This section contains operational playbooks for common failure scenarios. These guides are designed to help on-call engineers quickly mitigate and resolve incidents.

## Core Playbooks

* **[High Latency](high_latency.md)**: Investigating and mitigating high latency or latency spikes.
* **[High Error Rate](high_error_rate.md)**: Handling elevated 5xx error rates.
* **[Database Failover](database_failover.md)**: Procedures for primary database failure.
* **[Memory Leak / OOM](memory_leak_oom.md)**: Diagnosing and mitigating OOM (Out of Memory) crashes.
* **[Disk Space Exhaustion](disk_space_exhaustion.md)**: Clearing disk space and handling full volumes.
* **[Certificate Expiry](certificate_expiry.md)**: Emergency rotation of expired certificates.
* **[Dependency Failure](dependency_failure.md)**: Handling failures of third-party APIs.
* **[Bad Deployment](bad_deployment.md)**: Rolling back bad deployments.

## How to Use These Playbooks

1.  **Assess Severity:** Determine the impact (SEV level) immediately.
2.  **Mitigate First:** Focus on restoring service before finding the root cause.
3.  **Follow the Steps:** Execute the investigation and mitigation steps in order.
4.  **Escalate:** If you are stuck or the SEV level increases, escalate to the appropriate subject matter expert.
