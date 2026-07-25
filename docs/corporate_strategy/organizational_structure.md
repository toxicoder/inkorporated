---
title: Organizational Structure Strategy
description: Organizational Structure Strategy for Inkorporated.
tags: [enterprise]
---

# Organizational Structure Strategy


**What's on this page**

- Core content for this topic in the Inkorporated enterprise OS.
- Practical guidance, roles, or standards as applicable.

**What this enables**


## Scaling phases

```mermaid
flowchart LR
  seed[Seed flat] --> seriesA[Functional VPs]
  seriesA --> seriesB[Matrix + squads]
  seriesB --> global[Tribes + regions]
```

- Consistent enterprise operations and decision-making.
- Shared language for humans and cyborg AI agents.

This document outlines the strategic philosophy behind Inkorporated's organizational design. While the [Job Role Organization](../job_roles/job_role_organization.md) defines specific roles and reporting lines, this strategy document explains *why* we organize this way and how we scale.

## 1. Core Philosophy: The Matrix

We utilize a **Matrix Organizational Structure** to balance two competing needs:
1.  **Functional Excellence (Verticals):** Deep expertise in specific domains (e.g., Engineering, Design, Finance).
2.  **Product Velocity (Horizontals):** Rapid delivery of value to customers through cross-functional collaboration.

### Why Matrix?
In a traditional hierarchy, engineers report to engineering managers, and designers report to design managers, often creating silos where "shipping" requires handing work over the wall. In a pure project-based structure, teams ship fast but technical debt accumulates because no one is looking after the long-term health of the code or design system.

The Matrix solves this by giving every individual two anchors:
*   **Your Manager (Vertical):** Responsible for your career, promotion, compensation, and skill development. They ensure *quality*.
*   **Your Squad Lead (Horizontal):** Responsible for the day-to-day work, backlog, and delivery. They ensure *speed*.

## 2. Squad Model (The "Two-Pizza" Rule)

Inspired by high-growth tech companies, our primary unit of execution is the **Squad**.

*   **Size:** A squad should be no larger than what can be fed by two pizzas (approx. 6-10 people).
*   **Autonomy:** Squads own a specific mission (e.g., "Checkout Experience" or "Cloud Infrastructure") and have all the skills necessary to execute it (Backend, Frontend, Design, Product) without external dependencies.
*   **Long-Lived:** Squads are stable. We bring work to the team, rather than forming temporary teams around work. This builds trust and domain context.

## 3. Scaling Phases

Our organizational structure evolves as we grow.

### Phase 1: The Commando Team (Seed - Series A)
*   **Structure:** Flat. Everyone reports to Founders.
*   **Focus:** Product-Market Fit.
*   **Strategy:** Speed above all. Roles are fluid. "All hands on deck."

### Phase 2: The Functional Split (Series B)
*   **Structure:** Introduction of VPs and Directors. distinct Engineering, Product, and Sales departments.
*   **Focus:** Scalability and process.
*   **Strategy:** Hiring functional leaders to build specialized teams. Implementation of the Matrix.

### Phase 3: The Tribe Model (Series C+)
*   **Structure:** Squads are grouped into "Tribes" or "Domains" (e.g., "Core Product Tribe", "Growth Tribe").
*   **Focus:** Managing complexity.
*   **Strategy:** Delegating P&L responsibility to Tribe leaders. Each Tribe operates almost like a mini-startup within the company.

## 4. Decision Making: DACI

To prevent the "matrix tax" (where multiple reporting lines slow down decisions), we utilize the **DACI** framework for strategic decisions:

*   **D = Driver:** The person responsible for corralling stakeholders and moving the project forward. (Usually a PM or Lead).
*   **A = Approver:** The *single* person who makes the final decision. (Usually a VP or Director).
*   **C = Contributors:** People with expertise who must be consulted (e.g., Legal, Security). They have a voice, but not a vote.
*   **I = Informed:** People who are told the decision after it is made.

## 5. Conway's Law

> "Organizations which design systems ... are constrained to produce designs which are copies of the communication structures of these organizations."

We explicitly architect our organization to mirror our desired software architecture. If we want a microservices architecture with decoupled components, we create decoupled squads with clear API boundaries between them.
