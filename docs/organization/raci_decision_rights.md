---
title: RACI and decision rights
description: Decision rights library for Inkorporated executives, squads, and control functions.
tags: [organization, raci, governance]
---

# RACI and decision rights

**What's on this page**

- Core decision table for product, security, finance, people, FO, and press
- How DACI and RACI interact with the matrix
- Escalation when Approver is unavailable

**What this enables**

- Fewer stalled decisions and fewer silent overrides
- Auditable accountability for high-risk actions (including cyborg-assisted ones)

## Legend

- **R** Responsible — does the work  
- **A** Accountable — single owner of outcome  
- **C** Consulted — two-way input required  
- **I** Informed — notified  

## Decision library (summary)

| Decision | A | R | C | I |
| --- | --- | --- | --- | --- |
| Product roadmap priority (squad) | CPO or delegate | PM | Eng, Design, GTM | Exec staff |
| Production break-glass access | CISO | On-call lead | SRE, Eng manager | CTO |
| Security exception | CISO | Requestor | Legal, SRE | CTO |
| Vendor > spend threshold | CFO | Requestor | Security, Legal | Controller |
| Public press statement | CEO / Comms | Comms | Legal, relevant VP | Board if material |
| Hire / level for VP | CEO | People | Board as needed | Exec team |
| FO personal disbursement | CEO | FO Director | Private legal/finance | — (restricted) |
| Corporate FO cost center budget | CFO | FO Director | CEO | Controller |
| Cyborg CRITICAL action | Human approver per policy | Cyborg + operator | Security/Legal as coded | Audit log |

Exact spend thresholds and approval matrices should use `{{ORG_LEGAL_NAME}}` finance policy attachments when customized.

## Escalation

If the Approver is unavailable beyond SLA:

1. Named delegate in writing  
2. Else skip-level with documented rationale  
3. Never “consensus by silence” for security, legal, or financial commitments  
