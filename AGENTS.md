# AGENTS.md

> A README for agents: context and instructions for AI coding tools working on the Inkorporated repository.

---

## Quick Start Commands

| Command | Description |
|---------|-------------|
| `./validate_config.sh` | Verify `.env` setup and permissions |
| `./validate_domain_config.sh` | Check for hardcoded domains |
| `./run_all_tests.sh` | Run full test suite |
| `bazel test //tests/...` | Run all Bazel tests |
| `bazel test //tests/config:config_security_scan` | Scan for secret leakage |

---

## Project Overview

**Name:** `inkorporated` (or `toxicoder/inkorporated`)

**Architecture:** Hybrid Cloud
- **Proxmox:** Persistent on-premises control plane
- **AWS/GCP:** Ephemeral burst capacity

**Core Tech Stack:** Bazel, Terraform, Ansible, Kubernetes (k3s), ArgoCD, Jekyll

---

## Setup & Configuration

### Dev Container

The project relies on the `.devcontainer` configuration.

### Secrets & Settings

| Setting | Details |
|---------|---------|
| **Source of Truth** | `.devcontainer/.env` |
| **Security** | File permissions **MUST** be set to `600` (`chmod 600 .devcontainer/.env`) |
| **Validation** | `validate_config.sh` checks for permissions and required MCP variables (e.g., `GH_TOKEN`, `PERPLEXITY_API_KEY`) |
| **Setup** | Copy `.devcontainer/.env.example` to `.devcontainer/.env` |

### Environments

| Location | Purpose |
|----------|---------|
| `config/environments/` | Configuration split by environment (dev, staging, prod) |
| `apps/environments/` | Application overrides |

---

## Directory Structure

```
inkorporated/
├── apps/              # GitOps manifests (ArgoCD Applications, ApplicationSets)
│   ├── shared/        # Base manifests
│   └── environments/  # Environment-specific overlays
├── config/            # Global and environment-specific configuration files
├── docs/              # Jekyll-based documentation
├── infrastructure/
│   ├── terraform/     # Infrastructure provisioning (Proxmox, AWS, GCP)
│   └── ansible/       # Configuration management (k3s installation)
└── tests/             # Validation scripts and Bazel test targets
```

---

## Build System (Bazel)

### Configuration

| Setting | Value |
|---------|-------|
| **Mode** | Workspace enabled (`--enable_workspace`) |
| **Bzlmod** | Disabled (`--noenable_bzlmod`) |

### Rules

- Use `rules_sh` for shell tests (defined in `WORKSPACE.bazel`)
- Load from specific files: `load("@rules_sh//shell:sh_test.bzl", "sh_test")`

### Data Attributes

| Rule | Description |
|------|-------------|
| Use direct labels | e.g., `//config:all_configs` |
| **No `glob()`** | Never use `glob()` in `data` attributes |
| `allow_empty=True` | Use for `glob()` in `srcs` where files might be missing |

---

## Infrastructure as Code

### Terraform

| Setting | Details |
|---------|---------|
| **Location** | `infrastructure/terraform/` |
| **State** | Use `moved` blocks in `main.tf` for refactoring |
| **Validation** | Run via `validate_terraform.sh` |

### Ansible

| Setting | Details |
|---------|---------|
| **Location** | `infrastructure/ansible/` |
| **Linting** | `ansible_lint_wrapper.sh` (skips if binary missing) |

---

## GitOps & Applications

### Manifests

Located in `apps/`.

### Domains

| Rule | Description |
|------|-------------|
| **NEVER hardcode** | Do not hardcode domains (e.g., `example.com`) in Ingress manifests |
| **Use templates** | Use templated references: `{{ .Env.DOMAIN_BASE }}` |
| **Validation** | `validate_domain_config.sh` enforces this |

---

## Documentation

### Location

`docs/`

### Structure

| Directory | Purpose |
|-----------|---------|
| `docs/guides/` | User handbooks and runbooks |
| `docs/architecture/` | Design documents and decisions |
| `docs/reference/` | Service reference documentation |
| `docs/status/` | Reports and implementation status |

### Configuration

| Setting | Details |
|---------|---------|
| **Config** | `_config.yml` uses `toxicoder/materialistic-jekyll` theme |
| **Links** | Internal links must be **relative** to the current file |
| **Link Target** | Target `.html` files, not `.md` (e.g., `../guides/overview.html`) |
| **Diagrams** | Use Mermaid (`.language-mermaid`) |

---

## Testing & Verification

### Pre-Submission Checklist

Before submitting changes, run:

1. **`./validate_config.sh`** — Verifies `.env` setup
2. **`./validate_domain_config.sh`** — Checks for hardcoded domains
3. **`./run_all_tests.sh`** — Runs the full suite (Bazel tests, infrastructure validation)

### Bazel Test Commands

```bash
# Run all tests
bazel test //tests/...

# Run specific test target
bazel test //tests/config:config_security_scan

# Run with verbose output
bazel test --test_output=errors //tests/...
```

---

## Code Style

### Style Guides

All code must follow the style guides in `docs/style_guides/`:

| Language | Location |
|----------|----------|
| Bash | `docs/style_guides/bash/` |
| C++ | `docs/style_guides/cpp/` |
| CSS | `docs/style_guides/css/` |
| Golang | `docs/style_guides/golang/` |
| HTML | `docs/style_guides/html/` |
| Java | `docs/style_guides/java/` |
| JavaScript | `docs/style_guides/javascript/` |
| JSON | `docs/style_guides/json/` |
| Kotlin | `docs/style_guides/kotlin/` |
| Markdown | `docs/style_guides/markdown/` |
| Protocol Buffers | `docs/style_guides/proto/` |
| Python | `docs/style_guides/python/` |
| Rust | `docs/style_guides/rust/` |
| SQL | `docs/style_guides/sql/` |
| Starlark | `docs/style_guides/starlark/` |
| TypeScript | `docs/style_guides/typescript/` |
| YAML | `docs/style_guides/yaml/` |
| Zsh | `docs/style_guides/zsh/` |

### Infrastructure Style

- **General:** `docs/style_guides/infra_style_guide.md`

---

## Dev Environment Tips

### For AI Agents

| Tip | Description |
|-----|-------------|
| **Read before write** | Always use `read_file` before editing any file |
| **Use specific paths** | Reference files with full paths from `/workspaces/inkorporated` |
| **Validate first** | Run `./validate_config.sh` before making changes |
| **Test after changes** | Run relevant tests after modifications |
| **Check style guides** | Refer to `docs/style_guides/` for language-specific rules |

### Navigation

```bash
# Find files by name
find . -name "*.tf" -type f

# Search for content
grep -r "DOMAIN_BASE" apps/

# List directory structure
tree -L 2 -I 'node_modules|\.git'
```

---

## PR Guidelines

### Title Format

```
[component] <Description>
```

**Examples:**
- `[terraform] Add AWS burst capacity module`
- `[k8s] Update ArgoCD application manifests`
- `[docs] Update deployment guide`

### Pre-Commit Checklist

- [ ] Run `./validate_config.sh`
- [ ] Run `./validate_domain_config.sh`
- [ ] Run `./run_all_tests.sh`
- [ ] All tests passing
- [ ] No hardcoded domains
- [ ] Documentation updated (if applicable)

---

## MCP & AI Integration

This repository is designed to work with MCP (Model Context Protocol).

### Configuration

| Setting | Location |
|---------|----------|
| **General Settings** | `cline_mcp_settings.json` |
| **Secrets** | `.devcontainer/.env` |

### Security

| Tool | Command |
|------|---------|
| **Secret Scanner** | `scan_secrets.sh` |
| **Bazel Test** | `bazel test //tests/config:config_security_scan` |

### Agent Capabilities

This repository provides the following capabilities for AI agents:

| Capability | Description |
|------------|-------------|
| **Infrastructure Provisioning** | Terraform modules for Proxmox, AWS, GCP |
| **Configuration Management** | Ansible playbooks for k3s installation |
| **GitOps Deployment** | ArgoCD Application manifests |
| **Validation** | Comprehensive test suite via Bazel |
| **Documentation** | Jekyll-based docs with Mermaid diagrams |

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `.env` permission denied | Run `chmod 600 .devcontainer/.env` |
| Bazel build fails | Check `WORKSPACE.bazel` and `MODULE.bazel` |
| Terraform validation fails | Run `./validate_terraform.sh` |
| Domain errors | Run `./validate_domain_config.sh` |

### Getting Help

1. Check `docs/guides/troubleshooting.md`
2. Review `docs/guides/overview.md` for architecture context
3. Examine `docs/architecture/ARCHITECTURE.md` for design decisions

---

*Last updated: 2026-04-11*