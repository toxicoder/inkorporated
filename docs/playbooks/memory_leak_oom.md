---
title: Memory Leak / OOM
description: Memory Leak / OOM for Inkorporated.
tags: [enterprise]
---

**Scenario:** Application containers are being killed by the OOM Killer, or memory usage is monotonically increasing.

## 1. Symptoms
* Alert: "Container Memory Usage > 90%".
* Alert: "Pod Restart Count High".
* Log entry: `OOMKilled` or `java.lang.OutOfMemoryError`.

## 2. Severity Assessment
* **SEV 1:** Rapid crash loop. Service is unavailable.
* **SEV 2:** Slow leak causing daily restarts. Performance degradation.
* **SEV 3:** High memory usage but stable.

## 3. Initial Verification
* **Kubernetes:** Check `kubectl get pods` for `Restarts` and `OOMKilled` status.
* **Metrics:** Check memory usage graph over the last 24 hours. Is it a sawtooth pattern (normal GC) or a ramp (leak)?

## 4. Investigation
1.  **Profile:**
    * **Java:** Trigger a heap dump (`jmap`). Analyze with Eclipse MAT.
    * **Go:** Capture a pprof heap profile (`go tool pprof`).
    * **Node:** Use `heapdump` or Chrome DevTools.
2.  **Logs:** Look for error messages preceding the crash.
3.  **Load:** Did traffic increase significantly?

## 5. Mitigation
* **Increase Limits:** Temporarily increase memory limits in `deployment.yaml`.
* **Restart:** Rolling restart of the deployment to clear memory.
* **Disable Features:** If a specific endpoint is leaking, disable it.

## 6. Resolution
* Analyze the heap dump to find the leaking object.
* Fix the code (e.g., closing connections, clearing caches).
* Tune Garbage Collection (GC) settings.

## 7. Escalation
* **Language Expert** (Java/Go/Node champion).
