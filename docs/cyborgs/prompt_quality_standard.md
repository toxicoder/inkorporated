---
title: Persona quality standard
description: Quality bars for Inkorporated cyborg system prompts and job role documentation.
tags: [cyborgs, quality, standards]
---

# Persona quality standard

**What's on this page**

- Minimum quality bars for system prompts and job role pages
- Required prompt sections for agent operability
- Validation expectations

**What this enables**

- Consistent, high-signal personas for humans and LLMs
- Automated checks via `docs/validate_persona_quality.py`

## System prompt floors

| Role class | Min prompt words | Min phrases | Min personalities |
| --- | --- | --- | --- |
| Absolute floor | 350 | 6 | 4 |
| Typical IC | 450 | 6 | 4 |
| Manager / lead | 550 | 7 | 5 |
| Executive / board | 600 | 8 | 5 |

### Required prompt sections

1. Identity and mission  
2. Scope of authority (decide / escalate / never)  
3. Core responsibilities  
4. Operating principles and anti-patterns  
5. Collaboration and artifacts  
6. Tools, knowledge docs, evidence standard  
7. Decision framework  
8. Communication style and example phrases  
9. Personality blend  
10. Safety and compliance (HITL, secrets, domains, FO firewall when `PERS*`)

## Job role page floors

| Class | Min page words |
| --- | --- |
| IC / specialist | 1,200 |
| Manager / director / squad lead | 1,400 |
| Executive / board | 1,600 |

Exclude: `index.md`, `job_role_organization.md`, `organization_chart.md`.

### Required sections

- Role-specific **What's on this page** / **What this enables**  
- Meta table (code, band, reports-to, security)  
- Job description, responsibilities, partners, KPIs  
- Cadence or average day  
- AI Agent Profile (full prompt)  
- Cyborg YAML link  
- Recommended reading  

## Sync rule

`cyborgs/<JOB_ID>.yaml` `system_prompt` must match the intent of the job role **AI Agent Profile**. Prefer YAML as machine SoT; regenerate roster after changes.

## Safety footer (always)

Every prompt ends with Inkorporated constraints:

- No secrets in outputs or commits  
- No hardcoded customer domains  
- CRITICAL / high-risk side effects need human approval  
- Family Office data stays in FO boundary  
