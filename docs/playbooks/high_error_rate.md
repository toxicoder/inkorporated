---
title: High Error Rate
description: High Error Rate for Inkorporated.
tags: [enterprise]
---

**Scenario:** Elevated rate of 5xx errors (Internal Server Errors).

## 1. Symptoms
* Alert: "5xx Rate > 1%".
* Users seeing "Something went wrong" pages.

## 2. Severity Assessment
* **SEV 1:** Error rate > 10%. Critical user flows blocked.
* **SEV 2:** Error rate > 1%. Non-critical flows affected.
* **SEV 3:** Elevated errors on low-traffic endpoints.

## 3. Initial Verification
* Check **Error Dashboard**.
* Identify the specific status code (500, 502, 503, 504).
    * **500:** Application logic crash / unhandled exception.
    * **502/504:** Upstream timeout or connection failure.
    * **503:** Service unavailable / overloaded.

## 4. Investigation
1.  **Logs:** Check application logs (Splunk/ELK) for stack traces.
    * Search for `ERROR` or `Exception`.
2.  **Recent Changes:** Did a deployment just happen?
3.  **Health Checks:** Are pods failing health checks and restarting?

## 5. Mitigation
* **Rollback:** If a recent deployment caused it, rollback immediately.
* **Restart:** Restart unhealthy pods.
* **Circuit Break:** If a dependency is failing, open the circuit breaker to fail fast.

## 6. Resolution
* Fix the bug causing the exception.
* Patch the dependency or configuration.

## 7. Escalation
* If related to core platform, page **Platform Team**.
