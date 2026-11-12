---
title: Cyborg deployment map
description: Namespaces, reliability tiers, and human-in-the-loop rules for Inkorporated cyborgs.
tags: [cyborgs, organization, security]
---

# Cyborg deployment map

**What's on this page**

- Kubernetes-oriented namespace layout for agent personas
- Security levels and human approval gates
- Family Office invocation restrictions
- Mapping to `cyborgs/*.yaml`

**What this enables**

- Safe multi-agent operation alongside humans
- Clear blast-radius boundaries for automation

## Namespaces (logical)

| Namespace | Personas |
| --- | --- |
| `cyborg-executive` | EXEC*, BOARD* assistants |
| `cyborg-development` | SWEN*, PROD engineering-adjacent |
| `cyborg-sre` | SREL*, platform reliability |
| `cyborg-security` | AppSec, GRC, SOC personas |
| `cyborg-gtm` | SALE*, MKTG*, COMM*, CSM* |
| `cyborg-ga` | FINC*, PEOP*, LEGL*, OPS*, REAL* |
| `cyborg-data` | DATA* |
| `cyborg-customer` | CUST* |
| `cyborg-family-office` | PERS* (**restricted**) |
| `cyborg-squad` | SQAD* orchestrators |

## Reliability & latency

Default from ported catalog: **FOUR_NINES** reliability tier and latency budget unless overridden. Heavy batch personas may use THREE_NINES.

## Security levels

| Level | Human approval | Examples |
| --- | --- | --- |
| CRITICAL | Always for side effects | CEO, CLO, FO, finance disbursement, security break-glass |
| HIGH | Required for prod/security changes | SRE, Security, Counsel |
| MEDIUM | Spot checks / sampling | IC builders, analysts |
| LOW | Informational agents | Read-only research assistants |

## Family Office rules

- Deploy only into `cyborg-family-office`
- `allowed_invokers` typically `EXEC0001` (CEO) and `PERS0001` (FO Director)
- Separate audit trail from corporate GTM agents
- Never train public models on FO conversation content

Machine specs live in repo-root [`cyborgs/`](https://github.com/toxicoder/inkorporated/tree/main/cyborgs). Human overview: [Cyborgs](../cyborgs/index.md).
