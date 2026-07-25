---
title: Git workflow
description: Git workflow for Inkorporated.
tags: [infrastructure]
---

# Git workflow

**What's on this page**

- Long-lived branches and short-lived branch naming
- Conventional-style commit messages
- Promotion from development to main
- Agent constraints (no push unless asked)

**What this enables**

- Clean history and a clear integration gate before production

## Long-lived branches

| Branch | Purpose |
| --- | --- |
| `development` | Primary integration; feature work lands here first |
| `main` | Production-ready, promoted deliberately |
| `dev` | Optional soak gate |

Never force-push `development` or `main`. Prefer linear history (rebase/squash).

## Short-lived branches

Create from latest `development` (hotfixes from `main`):

- `feature/<short-description>`
- `fix/<short-description>`
- `hotfix/<short-description>`
- `chore/<short-description>`
- `docs/<short-description>`

## Commits

```text
<type>: <short summary in imperative mood>

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `hotfix`, `chore`, `docs`, `refactor`, `test`, `ci`, `build`.

Full detail: [CONTRIBUTING.md](https://github.com/toxicoder/inkorporated/blob/main/CONTRIBUTING.md).
