---
title: Observability
description: Observability for Inkorporated.
tags: [infrastructure]
---

# Observability


**What's on this page**

- Documentation for this infrastructure topic.

**What this enables**


## Telemetry pipeline

```mermaid
flowchart LR
  apps[Workloads] --> prom[Prometheus]
  apps --> promtail[Promtail]
  promtail --> loki[Loki]
  prom --> graf[Grafana]
  loki --> graf
  prom --> alert[Alertmanager]
```

- Operators can deploy and operate Inkorporated systems confidently.

## Monitoring Stack
- **Grafana**: Single pane dashboard for every service + Proxmox + pfSense
- **Loki**: Unified logs (pods + hosts)
- **Alerts**: For failures, resource exhaustion, backup issues, pfSense events

## Metrics Collection
- **Prometheus**: Metrics scraping from all services
- **Built-in exporters**: For most applications
- **Custom exporters**: Where needed
