---
title: Template variables
description: Placeholder variables used in Inkorporated legal and policy templates.
tags: [templates, policy]
---

# Template variables

**What's on this page**

- Canonical `{{VARIABLE}}` dictionary
- Where narrative uses “Inkorporated” vs template vars
- Guidance for operators customizing a deployment

**What this enables**

- Reusable enterprise templates without hardcoding a single legal entity everywhere
- Safer multi-tenant or white-label use of this monorepo

## Rules

1. **Narrative docs** (strategy, org, engineering culture) use the brand **Inkorporated**.
2. **Legal, tax, ToS, and many policies** use template variables for entity-specific values.
3. Replace variables before production legal reliance. These materials are **templates, not legal advice**.

## Dictionary

| Variable | Meaning |
| --- | --- |
| `{{ORG_LEGAL_NAME}}` | Registered legal entity name |
| `{{ORG_DBA}}` | Trade name if different |
| `{{DOMAIN_BASE}}` | Primary DNS zone (never hardcode in Ingress) |
| `{{SUPPORT_EMAIL}}` | Customer support contact |
| `{{SECURITY_EMAIL}}` | Security reports |
| `{{PRIVACY_EMAIL}}` | Privacy / DSR contact |
| `{{HR_EMAIL}}` | People / HR contact |
| `{{LEGAL_EMAIL}}` | Legal contact |
| `{{LEGAL_ENTITY_JURISDICTION}}` | Incorporation jurisdiction |
| `{{BOARD_CONTACT}}` | Board liaison contact |
| `{{DATA_PROTECTION_OFFICER}}` | DPO name/contact if appointed |

## Implementation notes

- GitOps manifests already require non-hardcoded domains; keep `{{DOMAIN_BASE}}` aligned with `config/` and environment overlays.
- Cyborg prompts that send external email must read contacts from config, not embed personal addresses.
