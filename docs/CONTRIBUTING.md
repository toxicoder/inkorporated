---
title: Contributing to the documentation
description: MkDocs page standards, local serve/build, and PR checklist for Inkorporated docs.
tags: [documentation, contributing, mkdocs]
---

# Contributing to the documentation

**What's on this page**

- How to preview and build the MkDocs site
- Required frontmatter and page structure
- Link and Mermaid rules for strict builds

**What this enables**

- Docs-as-code quality matching the DGX lab gold standard
- Consistent enterprise OS and infrastructure documentation

For code, GitOps, Terraform, and Ansible conventions see [project-conventions.md](project-conventions.md). Root [CONTRIBUTING.md](https://github.com/toxicoder/inkorporated/blob/main/CONTRIBUTING.md) covers branching and PRs.

## Quick start

```bash
bazelisk run //docs:manage-docs -- serve          # live preview
bazelisk test //docs:build            # production build
bazelisk run //docs:manage-docs -- preview        # strict build + static serve
bazelisk run //docs:manage-docs -- status
```

Requires Python 3.11+ (venv auto-created under `.venv-docs/`).

## Information architecture

- **Home / Getting Started** — new operators
- **Organization / Strategy / Roles / Cyborgs** — enterprise OS
- **Engineering / Policies** — how we work
- **Infrastructure** — hybrid cloud, GitOps, services
- **Contributing** — conventions and docs rules
- **Status** — reports

Every major section should have a solid index page. Keep `mkdocs.yml` `nav` in sync when adding pages.

## Frontmatter (required)

```yaml
---
title: Clear Descriptive Title
description: One-sentence summary for search and previews.
tags: [enterprise, infrastructure]
---
```

## Content guidelines

Every page should open with:

**What's on this page**

- Bullets for sections, diagrams, tables

**What this enables**

- Reader outcomes

Additional rules:

- Prefer admonitions (`!!! note`, `!!! warning`) and tabs for alternatives
- All fenced code blocks must specify a language (`bash`, `yaml`, `text`, `mermaid`, …)
- Use Mermaid for architecture and org diagrams
- Links inside `docs/`: relative `.md` paths
- Links to repo-root files outside `docs/`: full GitHub URLs (strict builds reject many `../` escapes)
- AI-assisted drafts must be human-reviewed before merge

## Multi-version publishing

CI/deploy uses **mike**:

- `main` → alias `latest` (default)
- `development` → alias `development`

Local builds do not require mike. Env stamps: `INK_DOCS_VERSION`, `MIKE_DOCS_VERSION`.

## Cyborg roster (auto-generated)

The visual cyborg catalog is **generated** from `cyborgs/*.yaml`:

```bash
# The generator runs automatically inside serve and build:
bazelisk run //docs:manage-docs -- serve
bazelisk test //docs:build
```

Outputs land in `docs/cyborgs/generated/` (cards, chips, persona pages). **Do not hand-edit** that tree. Prefer Mermaid diagrams in hand-written pages; the generator also emits org/stats graphs.

## Mermaid

Use fenced `mermaid` blocks for architecture, flows, and org sketches. Keep graphs small and labeled; put detail in prose.

## Links (multi-version / branch-aware)

Docs deploy with **mike** under version aliases (`latest` from `main`, `development` from `development`). Linking rules:

| Target | How to link |
| --- | --- |
| Another docs page | **Relative** path to the `.md` file, e.g. `[Overview](../guides/overview.md)` |
| Repo file outside `docs/` (e.g. `cyborgs/*.yaml`) | Full GitHub URL with branch **`main`**: `https://github.com/toxicoder/inkorporated/blob/main/...` |
| Do not | Hardcode `blob/development`, absolute `github.io/inkorporated/...` without `/latest/` or `/development/`, or HTML `href="page.md"` in generated UI |

At build time, `docs/hooks.py` rewrites GitHub `main`/`development` to the active docs git ref (`INK_DOCS_VERSION` / `MIKE_DOCS_VERSION`). Intra-docs relative links stay inside the current version alias automatically.

Validate:

```bash
# Runs docs/validate_docs_links.py --strict, then the MkDocs strict build:
bazelisk test //docs:build
```

## Before submitting a docs PR

- [ ] `bazelisk test //docs:build` passes
- [ ] New pages added to `mkdocs.yml` nav when user-facing
- [ ] Cyborg YAML changes regenerate cleanly
- [ ] No secrets; template vars used in legal/policy where appropriate
- [ ] Org/role/cyborg cross-links updated if catalog changed
