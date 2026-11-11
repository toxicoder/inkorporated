# Inkorporated Repository Agent Guide

This document is the **AI agent workflow** guide for the Inkorporated monorepo.

**Shared conventions** (naming, formatting, safety, docs, testing, change discipline) live in [docs/project-conventions.md](docs/project-conventions.md). Read that document first. Human contribution hub: [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 1. Project overview

*   **Name:** `inkorporated` (toxicoder/inkorporated)
*   **Identity:** Hybrid-cloud infrastructure **and** enterprise operating system documentation (roles, policies, cyborgs, org design)
*   **Architecture:** Proxmox control plane + AWS/GCP burst; k3s; ArgoCD; Bazel; MkDocs Material docs
*   **Core stacks:** Terraform, Ansible, Kubernetes (k3s), ArgoCD, Jekyll legacy retired in favor of **MkDocs**

---

## 2. Branching, commits, PRs (agents)

Full rules: [CONTRIBUTING.md](CONTRIBUTING.md).

| Branch | Purpose |
| --- | --- |
| `development` | Primary integration — land work here |
| `main` | Production after deliberate promotion |

- Create short-lived branches: `feature/`, `fix/`, `chore/`, `docs/`, `hotfix/` (hotfixes from `main`)
- Conventional-style commits: `type: imperative summary`
- **Never force-push** `development` or `main`
- **Do not `git push`, open PRs, or create tags** unless the user **explicitly** asks
- Prefer local commits the user can review

---

## 3. Environment setup

*   **Dev container:** `.devcontainer/`
*   **Secrets SoT (local):** `.devcontainer/.env` — **MUST** be mode `600`; never commit
*   **Template:** copy `.devcontainer/.env.example` → `.devcontainer/.env`
*   **Validate:** `bazelisk test //:validate_config_template` (against the
    committed template) and `bazelisk test //:validate_domain_config`.
    `//:validate_config` checks the operator's own `.env` and is a host lane.

Environments: `config/environments/`, `apps/environments/`.

---

## 4. Directory structure

| Path | Purpose |
| --- | --- |
| `apps/` | GitOps manifests |
| `config/` | Global and env configuration |
| `docs/` | MkDocs site content |
| `cyborgs/` | Machine agent persona YAML |
| `infrastructure/terraform/` | Provisioning |
| `infrastructure/ansible/` | Configuration management |
| `tests/` | Validation scripts / Bazel tests |
| `mkdocs.yml` | Docs site navigation and theme |

---

## 5. Build system (Bazel)

*   Bzlmod (`MODULE.bazel`) with the version pinned in `.bazelversion`; Bazel 9
    has no WORKSPACE, so `common --enable_workspace=false`
*   Shell tests: `load("//build:defs.bzl", "repo_sh_test")`, which wraps
    `@rules_shell//shell:sh_test.bzl` (Bazel 9 removed native `sh_test` and
    left `test_suite` as a no-op stub)
*   **No `glob()`** in `data` attributes; use direct labels
*   A surviving `glob()` in `srcs` carries an inline `# glob-policy: <reason>`
    and stays inside the budget `//tools/bazel/sh:glob_budget` enforces
*   One entry point: `bazelisk test //:gate` (see §10)

---

## 6. Infrastructure as Code

### Terraform

*   Location: `infrastructure/terraform/`
*   Use `moved` blocks when refactoring
*   Validate via repo terraform validation targets / scripts

### Ansible

*   Location: `infrastructure/ansible/`
*   Lint: `bazelisk test //infrastructure/ansible:ansible_lint` — fails under
    `REQUIRE_LINT_TOOLS=1` when `ansible-lint`, `yamllint` or the
    `community.general` collection is missing; install the collection with
    `ansible-galaxy collection install -r infrastructure/ansible/requirements.yml`
*   Linter versions are pinned in `tools/bazel/lint-requirements.txt` and
    install into a prefix with its own interpreter, so the lane runs the same
    release everywhere; `bazelisk run //:doctor` reports a tool that is on PATH
    but cannot run as BROKEN and exits non-zero

---

## 7. GitOps & applications

*   Manifests in `apps/`
*   **NEVER** hardcode domains in Ingress — use templated domain config / `{{DOMAIN_BASE}}`
*   Enforced by `bazelisk test //:validate_domain_config`

---

## 8. Documentation (MkDocs)

*   Engine: **MkDocs Material** + **mike** multi-version (`latest` / `development`)
*   Local: `bazelisk run //docs:manage-docs -- serve` | `-- build --strict`
*   Every page: YAML frontmatter + **What's on this page** / **What this enables**
*   Mermaid via pymdownx fences
*   Links inside docs: relative `.md` paths
*   New user-facing pages must be added to `mkdocs.yml` `nav`
*   Full rules: [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)

Enterprise OS trees include `organization/`, `corporate_strategy/`, `job_roles/`, `cyborgs/`, `policies/`, `engineering_standards/`, interviews, training, etc.

---

## 9. Cyborgs (agent personas)

*   Machine specs: `cyborgs/<JOB_ID>.yaml`
*   Schema: [docs/cyborgs/schema.md](docs/cyborgs/schema.md)
*   CRITICAL / Family Office personas: human approval + restricted invokers
*   Keep job role pages and YAML in sync when editing prompts

---

## 10. Verification

Before considering a task done:

```bash
bazelisk test //:gate                          # the whole hermetic lane; the
                                               # answer to "is this repo green?"
bazelisk test //:fast                          # the same lanes minus the slow
                                               # checks, while you iterate
bazelisk run  //:doctor                        # which host tools the gates need
bazelisk test //:validate_config_template      # when env/config touched
bazelisk test //:validate_domain_config        # when apps/ingress touched
bazelisk test //docs:build                     # when docs touched (host lane)
```

---

## 11. MCP & AI integration

*   MCP settings: `cline_mcp_settings.json` (non-secret) + `.devcontainer/.env` (secrets)
*   Security scan: `//tests/config:config_security_scan`
*   Never commit API keys or agent auth state

---

## 12. Safety invariants (non-negotiable)

1. No secrets in git  
2. No hardcoded customer domains  
3. No push/PR/tag without explicit user request  
4. Cyborg CRITICAL side effects need human approval  
5. Do not disable domain or secret scanners without design review  
