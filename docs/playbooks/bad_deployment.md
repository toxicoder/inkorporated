---
title: Bad Deployment
description: Bad Deployment for Inkorporated.
tags: [enterprise]
---

**Scenario:** A recent code deployment has caused a regression, crash, or SEV.

## 1. Symptoms
* Alert fires immediately after a deployment pipeline finishes.
* Spike in Error Rate or Latency coinciding with "Release vX.Y.Z".
* User reports of broken UI/features.

## 2. Severity Assessment
* **SEV 1:** Deployment broke the site completely.
* **SEV 2:** Major feature regression.
* **SEV 3:** Minor bug introduced.

## 3. Initial Verification
* **Correlate:** Match the start time of the incident with the deployment timestamp.
* **Check Scope:** Is it only affecting the canary/staging environment or production?

## 4. Investigation
* **Check Logs:** Look for new error types introduced in this version.
* **Diff:** Compare code changes between the current version and the previous one.
* **Health Checks:** Are pods failing to start (CrashLoopBackOff)?

## 5. Mitigation
* **Immediate Rollback:** Do not debug forward. Revert to the last known good version (Previous Release).
    * `kubectl rollout undo deployment/frontend`
    * Or click "Revert" in the CI/CD UI.
* **Lock Deploys:** Freeze the deployment pipeline to prevent others from deploying on top.

## 6. Resolution
* Reproduce the bug in a lower environment.
* Fix the bug (Roll Forward) or Revert the commit (Git Revert).
* Add a test case to prevent recurrence.

## 7. Escalation
* **Release Manager** / **Author of the Change**.
