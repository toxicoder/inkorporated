---
title: Cyborg operating model
description: Supervision, audit, and kill switches for Inkorporated agent personas.
tags: [cyborgs, operations, security]
---

# Cyborg operating model

**What's on this page**

- Human supervision model
- Audit and retention expectations
- Kill switches and break-glass
- Evaluation before production enablement

**What this enables**

- Safe scale-out of agents across enterprise functions

## Supervision

| Tier | Supervision |
| --- | --- |
| CRITICAL | Human approval every side-effecting action |
| HIGH | Approval for prod/security/legal; async review otherwise |
| MEDIUM | Sampling review + automated policy checks |
| LOW | Automated only with rate limits |

## Audit

- Log: actor (human), cyborg id, tools invoked, decision summary, timestamp
- Retain per [document retention policy](../policies/document_retention_policy.md) and legal holds
- FO logs segregated and access-controlled

## Kill switches

1. Disable namespace admission (deploy layer)
2. Revoke tool credentials
3. Mark cyborg `priority` drained / offline in catalog
4. Incident response if misuse suspected

## Evaluation checklist

- [ ] Prompt matches job responsibilities  
- [ ] Tools are least privilege  
- [ ] knowledge_docs are current  
- [ ] Security level correct  
- [ ] Red-team / abuse cases considered for GTM and support bots  
