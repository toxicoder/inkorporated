---
title: High Latency
description: High Latency for Inkorporated.
tags: [enterprise]
---

**Scenario:** 99th percentile (p99) latency is elevated beyond the SLO threshold (e.g., > 500ms).

## 1. Symptoms
* Monitoring alerts for "High Latency > 500ms".
* Customer reports of slow page loads or timeouts.
* Increase in 504 Gateway Timeout errors.

## 2. Severity Assessment
* **SEV 1:** All users experiencing > 2s latency. Site unusable.
* **SEV 2:** Significant subset of requests slow. p99 > 1s.
* **SEV 3:** Minor regression. p99 > 500ms.

## 3. Initial Verification
* Check the **Latency Dashboard** in Grafana/Datadog.
* Is the spike global or regional?
* Is it affecting a specific endpoint or service?

## 4. Investigation
1.  **Check Resources:**
    * CPU/Memory usage on application pods.
    * Database CPU/IOPS.
2.  **Check Dependencies:**
    * Is a downstream service (Redis, DB, External API) slow?
    * Check dependency latency metrics.
3.  **Check Traffic:**
    * Is there a spike in throughput (RPS)?
    * Is it a DDoS attack or legitimate traffic?

## 5. Mitigation
* **Scale Up:** Increase replica count for the affected service (HPA).
* **Shed Load:** Enable rate limiting or drop non-critical traffic.
* **Restart:** If a specific pod is stuck, restart it.
* **Disable Features:** Turn off expensive features via feature flags.

## 6. Resolution
* Identify the code change or query causing the slowness.
* Optimize or revert the change.
* Add caching or indexes.

## 7. Escalation
* If database is the bottleneck, page **Data Engineering**.
* If network related, page **Infrastructure**.
