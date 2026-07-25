---
title: Tax Strategy & Compliance
description: Tax Strategy & Compliance for Inkorporated.
tags: [enterprise]
---

# Tax Strategy & Compliance


**What's on this page**

- Core content for this topic in the Inkorporated enterprise OS.
- Practical guidance, roles, or standards as applicable.

**What this enables**

- Consistent enterprise operations and decision-making.
- Shared language for humans and cyborg AI agents.

This document outlines Inkorporated's approach to global tax compliance, optimization, and risk management. Our strategy is to pay the correct amount of tax in every jurisdiction while leveraging legal incentives to fuel R&D and growth.

## 1. Research & Development (R&D) Tax Credits

As a technology company, our largest investment is in engineering. We aggressively substantiate and claim R&D tax credits.

### Section 41 (US Federal)
*   **Qualified Research Expenses (QREs):** We track engineering wages, cloud computing costs (AWS/GCP) used for dev/test environments, and US-based contractor fees.
*   **The 4-Part Test:** To qualify, activities must:
    1.  Be technological in nature.
    2.  Be for a permitted purpose (new/improved product or process).
    3.  Eliminate technical uncertainty.
    4.  Follow a process of experimentation.

**Action:** Engineering Managers must maintain documentation (Jira tickets, Design Docs) that proves the "uncertainty" and "experimentation" involved in their work.

## 2. Qualified Small Business Stock (QSBS)

We structure the company to maintain **QSBS (Section 1202)** eligibility for as long as possible.
*   **Benefit:** If eligibility is maintained, founders and early employees may exclude up to 100% of capital gains from federal tax (up to $10M or 10x basis) upon exit, provided the stock is held for 5+ years.
*   **Constraint:** The company must remain a C-Corp and have less than $50M in gross assets at the time of stock issuance.

## 3. Transfer Pricing (International)

As we expand globally, we adhere to the **Arm's Length Principle** mandated by the OECD.
*   **Model:** We typically operate on a **"Cost Plus"** basis for international subsidiaries.
    *   *Example:* The UK subsidiary incurs £1M in costs (salaries, rent). The US Parent pays the UK subsidiary £1M + X% markup. The UK entity pays tax on that small markup, while the US Parent deducts the full cost.
*   **Risk:** Incorrect transfer pricing is the #1 audit risk for multinational tech companies. We engage Big 4 accounting firms for periodic Transfer Pricing Studies.

## 4. Sales Tax & Nexus (Wayfair Decision)

In the US, we must collect sales tax in any state where we have **Nexus**.
*   **Physical Nexus:** Having an employee, office, or server in a state.
*   **Economic Nexus:** Exceeding a revenue or transaction threshold (e.g., $100k sales or 200 transactions) in a state, even without physical presence.

**Strategy:** We utilize automated tax compliance software (e.g., Avalara, Stripe Tax) to calculate and remit sales tax in real-time.

## 5. Stock-Based Compensation (409A)

To issue stock options without incurring immediate tax liabilities for employees, we must issue them at **Fair Market Value (FMV)**.
*   **409A Valuation:** We commission an independent 409A valuation from a third-party firm at least every 12 months, or after any "material event" (e.g., a new funding round).
*   **Compliance:** Issuing options below FMV triggers severe tax penalties for employees (20% surtax + interest).

## 6. NOL Strategy (Net Operating Losses)

In growth years where the company operates at a loss, we accrue **Net Operating Losses (NOLs)**.
*   **Carryforward:** These losses can be carried forward indefinitely to offset future taxable income when the company becomes profitable.
*   **Section 382 Limitation:** If the company undergoes an "Ownership Change" (cumulative >50% change in ownership over 3 years), the ability to use these NOLs is limited. This is a critical consideration during fundraising rounds.
