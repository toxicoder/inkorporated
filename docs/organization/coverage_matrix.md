---
title: Coverage matrix
description: Tracking job roles, interviews, cyborgs, and org-chart presence.
tags: [organization, coverage]
---

# Coverage matrix

**What's on this page**

- How we track completeness of the enterprise catalog
- Current baseline after initial port
- Target: ≥200 roles with 1:1 cyborg YAML

**What this enables**

- Honest progress tracking during saturation work
- CI-friendly validation later (`scripts/validate_cyborg_catalog.sh`)

## Status snapshot

| Dimension | Count (approx) | Notes |
| --- | --- | --- |
| Job role pages | **217** | Devset port + full enterprise saturation |
| Interview guides (ported) | ~99 | Language + original role guides; many new roles still need dedicated interview packs |
| Cyborg YAML | **201** | Port + expansion; coded personas |
| Target roles + cyborgs | ≥200 | **Met** — deepen prompts/interviews next |

## Required columns (per role code)

| Column | Meaning |
| --- | --- |
| Role code | e.g. `EXEC0001` |
| Job page | Path under `docs/job_roles/` |
| Interview | Path under `docs/interview_questions/` or `n/a` for squads |
| Cyborg YAML | `cyborgs/<code>.yaml` |
| Org chart | Mentioned in master or pillar chart |
| Level band | Lx / Mx / Exec |

## Backlog themes for saturation

Board/governance, COO/CISO/CDO and expanded C-suite, platform/ML/staff ladder exemplars, AppSec/SOC/GRC, support L1–L3/TAM/PS, RevOps/PMM/demand gen, tax/treasury/IA/procurement, corporate IT, regional GMs, additional squads + SQAD cyborgs.

Regenerate machine index: see `cyborgs/_index.yaml`.
