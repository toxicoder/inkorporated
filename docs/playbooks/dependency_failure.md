---
title: Dependency Failure
description: Dependency Failure for Inkorporated.
tags: [enterprise]
---

**Scenario:** A critical third-party API (e.g., Stripe, Twilio) or internal downstream service is down.

## 1. Symptoms
* High error rate (502/504) on endpoints calling the dependency.
* Log errors: `Connection refused`, `Timeout`, `Upstream unavailable`.
* Vendor Status Page shows an outage.

## 2. Severity Assessment
* **SEV 1:** Critical path blocked (e.g., Payments down).
* **SEV 2:** Non-critical feature broken (e.g., Email notifications delayed).
* **SEV 3:** Minor degradation.

## 3. Initial Verification
* Check **Vendor Status Page**.
* Check internal **Dependency Dashboard** (latency/error rate).
* Is it a timeout or a hard failure?

## 4. Investigation
* Is the issue global or regional?
* Did we exceed a rate limit (`429 Too Many Requests`)?
* Did we change our API keys or configuration?

## 5. Mitigation
* **Enable Circuit Breaker:** Open the circuit to fail fast and stop cascading failures.
* **Fallback:** Switch to a fallback provider (e.g., SendGrid -> Mailgun) if implemented.
* **Graceful Degradation:** Serve a cached version or a default response.
* **Rate Limit:** Limit our calls to the dependency if we are being throttled.

## 6. Resolution
* Monitor until the vendor resolves the issue.
* Re-close the circuit breaker once health is restored.
* Retry failed jobs (if idempotent).

## 7. Escalation
* **Vendor Support**.
