---
title: Matrix model
description: Functional verticals versus cross-functional squads at Inkorporated.
tags: [organization, matrix]
---

# Matrix model

**What's on this page**

- Why Inkorporated uses a matrix
- Vertical vs squad responsibilities
- DACI to avoid the “matrix tax”
- Conway’s Law implications for platform boundaries

**What this enables**

- High craft quality and high shipping velocity at the same time
- Clear ownership when two managers touch one person

## Verticals (managers own quality)

| Vertical | Owns |
| --- | --- |
| Engineering | Code health, architecture standards, hiring eng talent |
| Product | Problem definition, prioritization craft, roadmaps |
| Design | Design system, research rigor, UX quality |
| GTM | Pipeline, brand, messaging quality |
| G&A | Controls, people systems, legal hygiene |
| Security | Risk posture, detections, secure defaults |
| Family Office | Executive support quality and confidentiality |

## Squads (leads own outcomes)

Squads are long-lived, ~6–10 people, mission-aligned (two-pizza). Examples:

- Platform Foundations, Developer Experience, Data Platform
- Growth / Acquisition, Monetization, Enterprise Launch
- Privacy/GDPR, Security Red Team, AI Ethics & Safety
- IPO / Audit Ready, Sustainability ESG, Internationalization

See [Specialized squads](../job_roles/specialized_squads_cross_functional_teams/index.md).

## DACI (decision speed)

| Letter | Meaning |
| --- | --- |
| **D** Driver | Moves work forward (often PM or EM) |
| **A** Approver | Single final decision-maker |
| **C** Contributors | Must be consulted (Legal, Security, …) |
| **I** Informed | Told after decision |

Full library: [RACI & decision rights](raci_decision_rights.md).

## Conway’s Law

We design squads and API ownership to match the software architecture we want. Platform squads own shared platforms; product squads consume them through versioned interfaces — not ad-hoc pings.
