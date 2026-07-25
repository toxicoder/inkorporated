---
title: On-Call Guide
description: On-Call Guide for Inkorporated.
tags: [enterprise]
---

Being on-call is a shared responsibility. It ensures our services remain
reliable and available for our customers. This guide sets expectations for
on-call engineers.

## Philosophy

* **You are not alone.** You have the support of your team and the organization.
  If you are stuck, escalate.
* **Health matters.** On-call should not be a burden that leads to burnout. We
  track "pager load" and take action if it becomes unmanageable.
* **Fix the root cause.** If you get woken up, the goal is to fix it so you (or
  your teammate) don't get woken up for the same reason again.

## Responsibilities

### Before Shift

* **Handover:** Sync with the previous on-call engineer. Review any ongoing
  issues, silenced alerts, or special context.
* **Access Check:** Ensure you have access to all necessary tools (PagerDuty,
  AWS/GCP console, Logs, Dashboards).
* **Schedule:** Verify your shift hours in the schedule.

### During Shift

* **Acknowledge Alerts:** Respond to pages within the SLA (15 mins for SEV 1).
* **Triage:** Determine the severity and impact of the issue.
* **Mitigate:** Focus on restoring service. Use the
  [Incident Management Process](incident_management.md).
* **Communication:** Keep stakeholders informed.
* **Documentation:** Log your actions and findings in the incident ticket.

### After Shift

* **Handover:** Brief the next on-call engineer.
* **Post-Mortems:** Follow up on any required post-mortems.
* **Cleanup:** Resolve or reassign any non-critical tickets created during your
  shift.

## Best Practices

* **Prepare:** Have your laptop and internet access ready. Don't go on a hike
  without signal while on-call.
* **Don't Panic:** Take a breath. Read the alert. Check the graphs.
* **Use Playbooks:** Refer to runbooks and playbooks for step-by-step resolution
  guides. If a playbook is missing or outdated, fix it.
* **Escalate:** If you can't solve the issue or need help, page the secondary
  on-call or a subject matter expert. It's better to wake someone up than to let
  an outage persist.
* **Tune Alerts:** If an alert is noisy (false positive) or not actionable, tune
  it or delete it. "Page Fatigue" is real and dangerous.
