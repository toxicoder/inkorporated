---
title: Post-Mortem Guide
description: Post-Mortem Guide for Inkorporated.
tags: [enterprise]
---

We learn more from our failures than our successes. A Post-Mortem (or COE -
Correction of Error) is a structured process to analyze incidents, understand
root causes, and prevent recurrence.

## Core Principle: Blamelessness

The goal of a post-mortem is **learning**, not punishment. We assume that
everyone involved had good intentions and made the best decisions they could
with the information they had at the time.

* **Bad:** "Engineer X pushed bad code."
* **Good:** "The deployment pipeline did not catch the regression in module Y
  because the test suite was missing coverage for this edge case."

## When to Write a Post-Mortem

* **SEV 1 & SEV 2 Incidents:** Mandatory.
* **SEV 3 Incidents:** Optional but recommended if there are valuable lessons.
* **Near Misses:** Recommended for high-risk situations that were narrowly
  avoided.

## Structure of a Post-Mortem

### 1. Summary

A brief overview of the incident. What happened? Who was affected? How long did
it last?

### 2. Impact

Quantify the impact.

* **Duration:** Start time to End time.
* **Users Affected:** Number or percentage of users.
* **Revenue Impact:** Estimated loss (if applicable).
* **Data Impact:** Data lost or corrupted.

### 3. Timeline

A detailed chronological list of events, from detection to resolution. Use UTC
time.

* `[10:00 UTC]` Monitoring alert fires for high latency.
* `[10:05 UTC]` On-call engineer acknowledges alert.
* `[10:15 UTC]` Incident declared. SEV 2.
* ...

### 4. Root Cause Analysis (5 Whys)

Ask "Why?" at least 5 times to peel back the layers of the problem and find the
systemic cause.

**Example:**

1. **Why did the site crash?** Because the database CPU spiked to 100%.
2. **Why did the CPU spike?** Because a heavy query was run frequently.
3. **Why was the query run frequently?** Because a new feature was released
   without caching.
4. **Why was it released without caching?** Because the load test didn't
   simulate realistic traffic patterns.
5. **Why didn't the load test simulate realistic traffic?** Because we lack a
   tool to mirror production traffic to staging. -> **Root Cause**

### 5. Lessons Learned

* **What went well?** (e.g., "Alerts fired immediately," "Rollback was fast")
* **What went wrong?** (e.g., "Logs were missing," "Playbook was outdated")
* **Where did we get lucky?**

### 6. Action Items (AI)

Concrete tasks to prevent recurrence. Each AI must have an **Owner** and a **Due
Date**.

* [Prevent] Implement traffic mirroring in staging. (Owner: @infra-team, Due:
  YYYY-MM-DD)
* [Detect] Add alert for high database query time. (Owner: @backend-team, Due:
  YYYY-MM-DD)
* [Mitigate] Update rollback playbook. (Owner: @oncall, Due: YYYY-MM-DD)
