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
*   **Validate:** `./validate_config.sh`, `./validate_domain_config.sh`

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

*   Workspace enabled (`--enable_workspace`); Bzlmod disabled (`--noenable_bzlmod`)
*   Shell tests: `load("@rules_sh//shell:sh_test.bzl", "sh_test")`
*   **No `glob()`** in `data` attributes; use direct labels
*   `allow_empty=True` for `glob()` in `srcs` when files may be missing

---

## 6. Infrastructure as Code

### Terraform

*   Location: `infrastructure/terraform/`
*   Use `moved` blocks when refactoring
*   Validate via repo terraform validation targets / scripts

### Ansible

*   Location: `infrastructure/ansible/`
*   Lint: `ansible_lint_wrapper.sh` (skips if binary missing)

---

## 7. GitOps & applications

*   Manifests in `apps/`
*   **NEVER** hardcode domains in Ingress — use templated domain config / `{{DOMAIN_BASE}}`
*   Enforced by `./validate_domain_config.sh`

---

## 8. Documentation (MkDocs)

*   Engine: **MkDocs Material** + **mike** multi-version (`latest` / `development`)
*   Local: `./docs/manage-docs.sh serve` | `build --strict`
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
./validate_config.sh          # when env/config touched
./validate_domain_config.sh   # when apps/ingress touched
./run_all_tests.sh            # full suite when feasible
./docs/manage-docs.sh build --strict   # when docs touched
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
