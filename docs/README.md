---
title: Docs directory
description: How the Inkorporated documentation site is organized and how to run it locally.
tags: [documentation]
---

# Documentation

**What's on this page**

- Site layout: content in `docs/`, Fumadocs app in `docs-site/`
- Preview, export, and gate commands from the repository root
- Pointers to enterprise OS and infrastructure content

**What this enables**

- Contributors can find, preview, and build the docs without leaving the repo root

## Build

From the repository root:

```bash
bazelisk run //docs:serve    # live dev server with hot reload (port 3005, PORT= to override)
bazelisk run //docs:docs     # regenerate derived pages, then the static export in docs-site/out/
bazelisk test  //docs:build  # the strict docs gate (host lane)
```

Content lives in `docs/`; the Fumadocs (Next.js App Router) app that renders it is `docs-site/`,
and its sidebar is `docs-site/lib/nav.json`. The toolchains are `python3` for the page generators
and Node.js 22+ with npm for the site (`bazelisk run //docs-site:install`).

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

Authoring rules, the nav workflow, and the PR checklist: [CONTRIBUTING.md](CONTRIBUTING.md).
Conventions for every stack: [project-conventions.md](project-conventions.md).
