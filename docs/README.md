---
title: Docs directory
description: How the Inkorporated documentation site is organized.
tags: [documentation]
---

# Documentation

**What's on this page**

- MkDocs Material site layout
- Local build commands
- Pointers to enterprise OS and infrastructure content

**What this enables**

- Contributors can find and build docs quickly

## Build

From the repository root:

```bash
./docs/manage-docs.sh serve
./docs/manage-docs.sh build --strict
```

Site config: [`mkdocs.yml`](https://github.com/toxicoder/inkorporated/blob/main/mkdocs.yml) at the repo root.

## Structure

| Tree | Content |
| --- | --- |
| `organization/` | Org charts, matrix, leveling, coverage |
| `corporate_strategy/` | Strategy and governance |
| `job_roles/` | Role catalog |
| `cyborgs/` | Human docs for agent personas (`cyborgs/*.yaml` is machine SoT at repo root) |
| `engineering_standards/`, `policies/`, `style_guides/` | How we work |
| `guides/`, `architecture/`, `reference/` | Infrastructure |
| `interview_questions/`, `onboarding/`, `training/` | People systems |

See [project-conventions.md](project-conventions.md) and [CONTRIBUTING.md](CONTRIBUTING.md).
