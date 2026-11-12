---
title: Contributing to the documentation
description: Fumadocs page standards, local preview and build, navigation, and the docs PR checklist.
tags: [documentation, contributing, fumadocs]
---

# Contributing to the documentation

**What's on this page**

- **Quick start** - the commands you run and the toolchains they need
- **Authoring** - frontmatter, the scan list, Markdown vs MDX, callouts, Mermaid, abbreviations
- **Navigation** - the generated sidebar and how a new page reaches it
- **Links and publishing** - ref-aware links, the `latest` and `development` aliases
- **Gates** - what CI runs on a docs change

**What this enables**

- **Previewing** a page locally before you push it
- **Writing** pages the site renders without a translation step
- **Landing** a new page where readers can find it
- **Passing** the docs gates on the first CI run

For code, GitOps, Terraform, and Ansible conventions see [project-conventions.md](project-conventions.md);
root [CONTRIBUTING.md](https://github.com/toxicoder/inkorporated/blob/main/CONTRIBUTING.md) covers
branching and PRs.

## Quick start

Every docs command runs from the repository root:

```bash
bazelisk run //docs:serve           # live dev server with hot reload (port 3005, PORT= to override)
bazelisk run //docs:docs            # regenerate derived pages, then the static export in docs-site/out/
bazelisk run //docs:generate        # the page generators only (no npm install, no export)
bazelisk run //docs:preview         # strict build, then serve the static export
bazelisk run //docs:status          # report toolchain, nav file, and export state
bazelisk run //docs:clean           # remove local build artifacts
bazelisk run //docs-site:install    # npm ci from the pinned docs-site/package-lock.json
```

The only toolchains are `python3` for the generators and Node.js 22+ with npm for the site; nothing
installs a docs virtualenv any more. `bazelisk run //:doctor` reports what the gates need from your
host.

## Information architecture

Home and Getting Started serve new operators; Organization, Strategy, Roles and Cyborgs carry the
enterprise OS; Engineering and Policies say how we work; Infrastructure covers hybrid cloud, GitOps
and services; Contributing holds these rules; Status carries reports. Every major section should
have a solid index page. The menu itself is one generated file, `docs-site/lib/nav.json`
(see [Navigation](#navigation)).

## Frontmatter (required)

```yaml
---
title: Clear Descriptive Title
description: One-sentence summary for search and previews.
tags: [enterprise, infrastructure]
---
```

Frontmatter is exactly `title`, `description`, and `tags`, and it must be valid YAML - quote a value
that contains a colon.

## Page structure

Every page opens with the scan list the site folds into a styled brief: a bold **What's on this
page** line, its bullet list, then **What this enables** and a second bullet list. Keep the pair in
that order and do not restyle it as a fence, an admonition, or a card grid.

- Lead with the outcome and the commands; theory comes later.
- Every fenced code block names a language (`bash`, `yaml`, `text`, `json`, ...).
- AI-assisted drafts must be human-reviewed before merge.

## Markdown or MDX

A page authored as plain markdown stays `.md`. A page that needs a JSX component, or that carries
raw HTML that must survive rendering, is authored as `.mdx` and must be well-formed JSX: void
elements self-closed, every tag closed, and literal braces escaped as `\{ \}`.

## Callouts, diagrams, abbreviations

- **Callouts** use the admonition syntax - `!!! warning "Cyborg CRITICAL actions"` followed by an
  indented body - and render as the site's Callout component.
- **Mermaid** diagrams are ordinary `mermaid` fences and render client-side. Keep graphs small and
  labeled; put the detail in prose.
- **Abbreviations** come from `docs/includes/abbreviations.md`
  (`*[API]: Application Programming Interface`) and become tooltips site-wide.

## Navigation

The sidebar is `docs-site/lib/nav.json`. It is generated, so you regenerate it and review the result
as a diff:

```bash
bazelisk run //docs:manage-docs -- build   # regenerates docs-site/lib/nav.json from the tree
bazelisk test //docs-site:nav_test         # verify the committed file matches
```

A page that is not in the navigation is reachable by URL but invisible in the menu, so a new page
must land in the nav.

## Adding a page

1. Author it under `docs/` as `.md` (or `.mdx`, above) with the frontmatter and the scan list.
2. Link it from the index page of its section.
3. Run `bazelisk run //docs:manage-docs -- build` and review the nav diff.
4. Preview with `bazelisk run //docs:serve`, then run the gates below.

## Links (ref-aware)

| Target | How to link |
| --- | --- |
| Another docs page | **Relative** path to the `.md` file, e.g. `[Org chart](organization/org_chart_master.md)`; from a nested page, walk up with `../`. The site resolves it to the published route, so links are not rewritten during the migration. |
| Repo file outside `docs/` (for example `cyborgs/*.yaml`) | Full GitHub URL with the trunk ref **`main`**: `https://github.com/toxicoder/inkorporated/blob/main/...`. Name a tag (`blob/vX.Y.Z/...`) when the target is a released artifact. |
| Do not | Link a ref that is neither trunk nor a tag, or hardcode an absolute `github.io/inkorporated/...` URL without `/latest/` or `/development/` |

Edit-this-page links follow the alias ref, driven by `INK_DOCS_VERSION` / `INK_DOCS_GIT_REF`. Check
relative links with `bazelisk test //docs:validate_links`.

## Multi-version publishing

`.github/workflows/deploy-docs.yml` keeps the two aliases, and both build from `main`:
**`latest`** is published from the release tag at
https://toxicoder.github.io/inkorporated/latest/, and **`development`** from the trunk checkout
at https://toxicoder.github.io/inkorporated/development/. The workflow takes the alias as an
input and runs each one under its own GitHub Environment (`production` and `staging`), so no
deploy path reads a branch name to decide what to publish.

Build one alias locally with `bazelisk run //docs-site:build-latest` or
`bazelisk run //docs-site:build-development`; `bazelisk run //docs-site:build` is the plain static
export and `bazelisk run //docs-site:dev` is the Next dev server.

## Cyborg roster (auto-generated)

The visual cyborg catalog is generated from `cyborgs/*.yaml`:

```bash
bazelisk run //docs:generate_cyborgs   # the cyborg roster generator only
bazelisk run //docs:generate           # every page generator, the roster included
```

Outputs land in `docs/cyborgs/generated/` (cards, chips, persona pages). **Do not hand-edit** that
tree; prefer Mermaid diagrams in hand-written pages.
`bazelisk test //docs:generated_render_current` fails when the committed render no longer matches
`cyborgs/*.yaml`, so regenerate and commit in the same change.

## Gates

| Command | What it checks |
| --- | --- |
| `bazelisk test //docs:build` | the strict docs gate: regenerates, validates links, builds (host lane) |
| `bazelisk test //docs:validate_links` | branch-aware relative-link check |
| `bazelisk test //docs:generated_render_current` | committed cyborg render matches `cyborgs/*.yaml` |
| `bazelisk test //docs:test_docs_site_render` | frontmatter, navigation, and static-export render checks |
| `bazelisk test //docs-site:suite` | typecheck, unit, nav, codemod, and hazard-audit gates |
| `bazelisk test //:gate` / `//:fast` | the whole hermetic lane / the same lanes minus the slow checks |

## Before submitting a docs PR

- [ ] `bazelisk test //docs:build` and `bazelisk test //docs-site:suite` pass
- [ ] New pages are in `docs-site/lib/nav.json` (regenerate, then review the diff)
- [ ] Frontmatter is `title`, `description`, `tags` only, and parses as YAML
- [ ] Cyborg YAML changes regenerate cleanly
- [ ] No secrets; template vars used in legal/policy where appropriate
- [ ] Org/role/cyborg cross-links updated if the catalog changed
