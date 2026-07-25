---
title: Cyborg schema
description: Field reference for cyborgs/*.yaml agent persona files.
tags: [cyborgs, schema]
---

# Cyborg schema

**What's on this page**

- Required and optional fields for persona YAML
- Security and deployment objects
- Conventions for Family Office and CRITICAL roles

**What this enables**

- Consistent agent authoring and validation scripts

## Top-level fields

| Field | Required | Description |
| --- | --- | --- |
| `job_id` | yes | Stable code (e.g. `EXEC0001`) |
| `display_name` | yes | Short agent name |
| `human_title` | yes | Full human job title |
| `category` | yes | e.g. AI |
| `sub_category` | yes | EXECUTIVE, ENGINEERING, … |
| `level_band` | recommended | Lx / Mx / Exec |
| `reports_to` | recommended | Manager job_id |
| `direct_reports` | optional | List of job_ids |
| `short_description` | yes | One paragraph |
| `system_prompt` | yes | Full operator prompt |
| `personalities` | recommended | Blend tags |
| `example_phrases` | recommended | Dialogue samples |
| `primary_functionality` | yes | List of focus areas |
| `deterministic_capabilities` | optional | Enum-like strings |
| `llm_capabilities` | yes | e.g. TEXT_GENERATION, REASONING |
| `tags` | yes | Search/filter tags |
| `tools_mcp` | recommended | Allowed tools/MCP servers |
| `knowledge_docs` | recommended | Paths under docs/ |
| `job_type` | yes | LLM or DETERMINISTIC |
| `deployment` | yes | namespace, SLA, reliability |
| `resources` | yes | cpu/memory/storage/network |
| `security` | yes | level, authn/z, HITL, invokers |
| `priority` | yes | Scheduling priority |
| `timeout_ms` | yes | Per-call timeout |
| `retry` | yes | Backoff config |
| `dependencies` | optional | Integrations |
| `kpi_owned` | optional | Metrics the persona optimizes |
| `escalation_path` | optional | Human chain |

## Security object

```yaml
security:
  level: CRITICAL  # NONE|LOW|MEDIUM|HIGH|CRITICAL
  encryption_required: true
  authentication_required: true
  authorization_required: true
  human_approval_required: true
  allowed_invokers: []  # empty = org default policy
```

Family Office (`PERS*`) should set restricted `allowed_invokers` and CRITICAL level.
