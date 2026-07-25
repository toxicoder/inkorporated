---
title: Database Failover
description: Database Failover for Inkorporated.
tags: [enterprise]
---

**Scenario:** Primary database is unresponsive, crashed, or experiencing high load requiring failover.

## 1. Symptoms
* Monitoring alerts: "Database Connection Refused", "DB CPU > 95%", "High Replication Lag".
* Application logs showing `ConnectionTimeout` or `SQLTransientConnectionException`.

## 2. Severity Assessment
* **SEV 1:** Primary DB down. Site is read-only or completely down.
* **SEV 2:** High latency on write operations. Replication lag > 1 minute.
* **SEV 3:** Transient connection errors.

## 3. Initial Verification
* **Check Connectivity:** Can you connect to the primary endpoint?
* **Check Dashboard:** Look at CPU, Memory, IOPS, and active connections.
* **Check Replication:** Is the replica healthy?

## 4. Investigation
1.  **Blocker Queries:** Run `SHOW FULL PROCESSLIST` (MySQL) or `SELECT * FROM pg_stat_activity` (Postgres) to find stuck queries.
2.  **Locking:** Check for deadlocks or long-running transactions.
3.  **Hardware:** Is the disk full? Is the instance out of memory?

## 5. Mitigation
* **Kill Queries:** Terminate long-running blocker queries.
* **Failover:**
    1.  Promote a Read Replica to Primary.
    2.  Update the application configuration / DNS to point to the new Primary.
    3.  Restart application pods to clear stale connection pools.
* **Scale Up:** Temporarily increase instance size (if using cloud RDS/Aurora).

## 6. Resolution
* Investigate why the primary failed (logs, metrics).
* Rebuild the old primary as a new replica.
* Optimize queries that caused the load.

## 7. Escalation
* **Data Engineering** / **DBA Team** immediately.
