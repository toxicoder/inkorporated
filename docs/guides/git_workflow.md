---
title: Git workflow
description: Trunk-based Git workflow - one long-lived trunk, short-lived prefixed branches, and promotion by tag.
tags: [infrastructure, git, branching]
---

# Git workflow

Inkorporated is trunk-based. `development` is the only long-lived branch, and everything
else is a short-lived branch that dies within days.

**What's on this page**

- **Trunk** - the one long-lived branch and what may land on it
- **Short-lived branches** - the allowed prefixes, the lifetime target, and the rebase rule
- **Commits** - the conventional-style summary every commit carries
- **Promotion** - how a release is cut, by tag and never by branch
- **Retirement** - which branch names this repo has left behind
- **Agent constraints** - no push, no PR, no tag without an explicit request

**What this enables**

- **Landing** work in days, with one gate to satisfy instead of several
- **Promoting** a build by naming one ref or digest, so no deploy path reads a branch name
- **Shipping** unfinished work on trunk safely, behind a flag that defaults off
- **Auditing** the repo for stale branch policy text, because there is one model to grep for

## The trunk

`development` is the trunk. It is the only branch that stays alive.

| Rule | Detail |
| --- | --- |
| One trunk | `development` only. No second integration branch, no soak branch, no release branch, no environment branch. |
| Cut from the tip | Branch from the tip of `development` before the first edit, never from a stale local copy. |
| Merge by pull request | The full gate (`bazelisk test //:gate`) runs on the pull request and on push to `development`. |
| Delete on merge | Deleting the remote branch is part of landing the work. |
| Lifetime target | Opened and merged within a few days; anything older than 14 days is re-based onto trunk or closed. |

```bash
git switch -c feature/argo-appset-hardening origin/development   # cut from the tip
# ... commit, then:
git fetch origin && git rebase origin/development                # trunk moved under you
```

Rebase your own branch when trunk moves. Never rebase, force-push, or rewrite a branch
someone else has pushed to; `development` itself is never rebased and never force-pushed.

## Short-lived branches

| Prefix | Use |
| --- | --- |
| `feature/` | New functionality |
| `fix/` | Non-urgent fixes |
| `refactor/` | No behavior change |
| `docs/` | Documentation only |
| `chore/` | Tooling, CI, dependency bumps, no user-visible behavior |
| `ci/` | CI and gate changes |
| `test/` | Tests only |
| `perf/` | Performance work |
| `build/` | Bazel and build-system changes |

An urgent production fix is a normal `fix/` branch into `development`, shipped by tagging
the tip that fixes the problem and rolling back by tagging an earlier one. There is no
hotfix branch and no parallel production line to back-merge.

Unfinished work ships on trunk behind a flag that defaults off. See
[Feature flags](#feature-flags) below and [configuration.md](configuration.md).

## Commits

```text
<type>: <short summary in imperative mood>

[optional body - why]

[optional footer]
```

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `build`, `perf`.

Summary at most 72 characters, imperative mood ("add", "fix", "update"). The body explains
*why* when the diff does not. Reference issues in the footer (`Closes #123`).

Full detail: [CONTRIBUTING.md](https://github.com/toxicoder/inkorporated/blob/development/CONTRIBUTING.md).

## Promotion

An environment is a set of values plus a place to run, so promotion names one ref or
digest. It never selects a branch.

| Environment | Value home | Promotion |
| --- | --- | --- |
| Docs `latest` | GitHub Environment `production`, alias chosen by the workflow input | Tag the tip: `git tag -a vX.Y.Z -m "Release vX.Y.Z"` |
| Docs `development` | GitHub Environment `staging`, built from the trunk checkout | Push to `development` |
| k3s / ArgoCD apps | `apps/environments/<env>/` plus the ArgoCD Application target | Commit that bumps the image tag |
| Terraform | `infrastructure/terraform/envs/<env>/` on one shared module | Plan and apply the same module revision per workspace |
| Ansible | `infrastructure/ansible/inventories/<env>/` and `group_vars/<env>.yml` | Rerun the same playbook against another inventory |
| Dev container / local | `.devcontainer/.env` (mode `600`, never committed) | Operator's own file |

Cutting a release is tagging, and the tag is what the deploy builds:

```bash
git fetch origin
git tag -a v1.4.0 -m "Release v1.4.0" origin/development
git push origin v1.4.0
```

Do not push tags from agent automation unless a maintainer explicitly asks.

## Feature flags

Every flag is declared once in [`config/flags.yaml`](https://github.com/toxicoder/inkorporated/blob/development/config/flags.yaml)
with `default: false`, an owner, an expiry, and exactly one reader, and is documented in
`.devcontainer/.env.example`. The gate runs both states. Precedence, highest first:
process environment, then `stacks.<deploy-target-name>.<FLAG>`, then
`flags.<FLAG>.environments.<env>`, then `flags.<FLAG>.default`.

```bash
bazelisk test //:gate                                    # flags off
FEATURE_EXAMPLE=1 bazelisk test //:gate                  # flags on
```

Retiring a flag deletes the declaration, the branch, and the off-path in one `chore:` pull
request.

## Retirement note

Two branch names left this repository in November 2026:

- `main` - the old production line. Its last two commits were merges of pull requests from
  `development` and it carried no patch that `development` lacked, so it is deleted after
  its tip SHA `7a7d7c7` is recorded. Releases are tags from `development`.
- `dev` - the optional soak gate. It held three README edits already upstream. A soak
  environment is a namespace and an inventory group, and it needs no branch.

The names above belong in this note alone. Docs, `CONTRIBUTING.md`, and `AGENTS.md` state
the trunk model.
