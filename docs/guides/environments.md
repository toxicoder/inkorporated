---
title: Environments
description: Environments as sets of values on one trunk - value homes, parameter parity, and promotion commands that name a ref.
tags: [infrastructure, environments, deployment, git]
---

# Environment Implementation Guide

An environment is a set of **values**, a **secret store**, and a **place to run**. It is not a
git branch. Every environment here is a checkout of `development`, the trunk, plus its own
values, and promotion names one ref or digest.

**What's on this page**

- **The model** - values, secrets, and flags split three ways
- **Value homes** - where each environment's values live
- **Parity** - the rule that keeps parameter names identical across environments
- **Promotion** - dev, trunk, stable, as pasteable commands
- **Secrets** - where a value must not be written down
- **Flags** - the one place a switch is declared
- **Gaps** - what is scaffolding today, stated plainly

**What this enables**

- **Running** two environments on one host without a branch to keep in sync
- **Promoting** by tagging, so a release is a ref you can hand to someone else
- **Auditing** any value by grepping one file, because each environment has one home
- **Passing** the config gates on the first try, because the keys match across environments

## The model

Split every difference between two environments three ways and give each its own home:

| Kind of difference | Home | Never here |
| --- | --- | --- |
| Value (domain, namespace, size, class) | `config/environments/<env>/`, `apps/environments/<env>/` | a branch, a hardcoded string in a manifest |
| Secret | the GitHub Environment, the cluster secret store, or `.devcontainer/.env` (mode `600`) | any committed file, `config/flags.yaml` included |
| Switch for unfinished work | `config/flags.yaml`, `default: false` | a branch that ships the feature half-done |

The supported environments, from `config/environment-config.yaml`: `dev`, `staging`,
`autopush`, `canary`, `prod`, and the `priv` and `uat` overlays. These are values, not refs:
the branch names this repo retired in November 2026 are listed once, in the
[retirement note](git_workflow.md#retirement-note), and share letters with these names by
coincidence.

## Value homes

| Environment | Config values | App overlay | Where it runs |
| --- | --- | --- | --- |
| `dev` | `config/environments/dev/{environment-config.yaml,domain-config.yaml}` | `apps/environments/dev/argo-cd/manifests.yaml` | your k3s control plane, or the dev container |
| `staging` | `config/environments/staging/` | `apps/environments/staging/argo-cd/manifests.yaml` | the soak cluster |
| `autopush` | `config/environments/autopush/` | add `apps/environments/autopush/` when it gets apps | the auto-push lane |
| `uat` | `config/environments/uat/` | add when it gets apps | the acceptance cluster |
| `canary` | `config/environments/canary/` | add when it gets apps | a slice of the prod fleet |
| `prod` | `config/environments/prod/` | `apps/environments/prod/argo-cd/manifests.yaml` | the prod fleet |
| `priv` | `config/environments/priv/` | add when it gets apps | the private network |
| Docs `latest` | GitHub Environment `production` | `.github/workflows/deploy-docs.yml`, alias input | GitHub Pages `/latest/` |
| Docs `development` | GitHub Environment `staging` | the same workflow, alias `development` | GitHub Pages `/development/` |
| Local dev container | `.devcontainer/.env` (never committed), template `.devcontainer/.env.example` | - | the container |

Machine-level values that are not per-environment live in `infrastructure/ansible/inventory/`
(`hosts.ini` plus `group_vars/`), and the provisioning shape lives in
`infrastructure/terraform/providers/<cloud>/` with sizing in
`infrastructure/terraform/profiles/<size>/`. Terraform has no per-environment directory yet;
when one environment needs different infrastructure, add `infrastructure/terraform/envs/<env>/`
on the shared modules rather than forking a module per environment.

Domains come from the templated domain config only. A manifest that hardcodes a customer
domain fails `bazelisk test //:validate_domain_config`.

## Parity

The same key must mean the same thing in every environment, so a value can be lifted from one
file to the next without a rename. `bazelisk test //tests/config:test_environment_inheritance`
checks the overlay chain and `.devcontainer/.env.example` for exactly this.

```bash
bazelisk test //tests/config:test_environment_inheritance   # overlay and key parity
bazelisk test //:validate_config_template              # the committed template
bazelisk test //:validate_domain_config                # no hardcoded customer domains
```

## Promotion

### dev - your own values, your own host

```bash
export ENVIRONMENT=dev
bazelisk test //:fast                    # the quick lane while you iterate
```

### trunk - where the change actually lands

```bash
git fetch origin
git switch -c feature/argo-tag-bump origin/development   # cut from the tip, before the edit
# edit values, run the gate in both flag states, commit
git fetch origin && git rebase origin/development        # trunk moved under you
bazelisk test //:gate
git push -u origin feature/argo-tag-bump                 # open the PR, merge, delete branch
```

Merging to `development` publishes the docs `development` alias under the `staging` GitHub
Environment. Nothing else deploys automatically.

### stable - name one ref

```bash
git fetch origin
git tag -a v1.4.0 -m "Release v1.4.0" origin/development
git push origin v1.4.0        # publishes the docs latest alias under the production Environment
```

Then move each environment onto that tag, each with its own one-line change:

| Mechanism | Promotion move | Command |
| --- | --- | --- |
| ArgoCD / k3s | one commit that bumps the image tag in the app manifest; ArgoCD syncs it | `argocd app sync infrastructure-<env>` after the tag commit lands |
| Ansible | the same playbook revision, another inventory | `ENVIRONMENT=staging ansible-playbook -i infrastructure/ansible/inventory infrastructure/ansible/playbooks/bootstrap-gitops.yml --check`, then the same line without `--check` |
| Terraform | the same module revision, planned per environment | copy `infrastructure/terraform/terraform.tfvars.example` to `infrastructure/terraform/envs/<env>/terraform.tfvars` and plan it: `terraform -chdir=infrastructure/terraform/providers/proxmox plan -var-file=../../envs/staging/terraform.tfvars` |
| Docs | the tag itself | the `v1.4.0` push above |
| Cyborgs / personas | a normal `chore:` PR; the roster regenerates | `bazelisk run //docs:generate_cyborgs` |

Every one of those names a tag, a digest, or an inventory - never a branch.

## Secrets

- GitHub Actions deploys read theirs from the **GitHub Environment** the job names
  (`production`, `staging`), with protection rules attached there.
- Cluster workloads read theirs from the cluster secret store, never from a values file.
- The dev container reads `.devcontainer/.env` (mode `600`, gitignored); commit only the
  `.env.example` key names with inert defaults.
- `bazelisk test //tests/config:config_security_scan` fails a commit that carries a real
  credential, and `bazelisk test //:validate_config` checks the operator's own file.

## Flags

One file declares every switch: [`config/flags.yaml`](https://github.com/toxicoder/inkorporated/blob/development/config/flags.yaml),
with `default: false`, an owner, an expiry, and one reader, and the key is listed in
`.devcontainer/.env.example`. Run any gate twice when you touch one:

```bash
bazelisk test //:gate                              # flags off
REQUIRE_LINT_TOOLS=1 bazelisk test //:gate         # flags on
```

## Gaps worth knowing

- `apps/environments/` holds overlays for `dev`, `staging`, and `prod` only. The other
  environments have config and no app overlay yet; adding one is a normal PR.
- Ansible carries a single inventory (`infrastructure/ansible/inventory/`) grouped by role.
  When two environments need different hosts, split it into `inventories/<env>/hosts.yml`
  plus `group_vars/<env>.yml` and keep one playbook.
- The ArgoCD ApplicationSet in `apps/argo-cd/manifests.yaml` still syncs at
  `targetRevision: HEAD`. That is fine for a soak lane and wrong for prod: pin it to a tag or
  a digest before the first prod app ships from it.
