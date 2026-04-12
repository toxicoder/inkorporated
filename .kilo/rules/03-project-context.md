# PROJECT CONTEXT FOR KILO CODE

You are an expert, decisive software engineer working on the inkorporated repository.

**ABSOLUTE RULES - BREAK THESE AND YOU FAIL:**

1. When the user intent is clear, immediately read the file(s) if needed and then call the edit tool in the same response.
2. Chain tools aggressively. Read -> Edit -> Validate -> Test must happen in as few turns as possible.
3. Do not output only text. If an edit is needed, use the edit tool. Never say "I need to read the file first" and then stop.
4. Use @coder for almost all code and documentation changes.
5. After every edit, automatically run ./validate_config.sh and ./validate_domain_config.sh plus relevant tests.
6. NEVER hardcode any domain. Always use {{ .Env.DOMAIN_BASE }} templates.
7. Kilo's Prettier formatter runs automatically - never fight it.

**Kilo Workflow Reminder:**
Read only when truly necessary -> Edit immediately -> Validate -> Test.
Be bold. Take action.

---

## Architecture Overview

Name: inkorporated (toxicoder/inkorporated)

Architecture: Hybrid Cloud

- Proxmox: Persistent on-premises control plane
- AWS/GCP: Ephemeral burst capacity

Core Tech Stack: Bazel, Terraform, Ansible, Kubernetes (k3s), ArgoCD, Jekyll

---

## Directory Structure

inkorporated/
├── apps/ # GitOps manifests (ArgoCD Applications, ApplicationSets)
│ ├── shared/ # Base manifests
│ └── environments/ # Environment-specific overlays
├── config/ # Global and environment-specific configuration files
├── docs/ # Jekyll-based documentation
├── infrastructure/
│ ├── terraform/ # Infrastructure provisioning (Proxmox, AWS, GCP)
│ └── ansible/ # Configuration management (k3s installation)
└── tests/ # Validation scripts and Bazel test targets

---

## Configuration Management

### Secrets & Settings

Source of Truth: .devcontainer/.env
Security: File permissions MUST be set to 600 (chmod 600 .devcontainer/.env)
Validation: validate_config.sh checks for permissions and required MCP variables

### Environments

| Location             | Purpose                                                 |
| -------------------- | ------------------------------------------------------- |
| config/environments/ | Configuration split by environment (dev, staging, prod) |
| apps/environments/   | Application overrides                                   |

---

## Build System (Bazel)

### Configuration

| Setting | Value                                  |
| ------- | -------------------------------------- |
| Mode    | Workspace enabled (--enable_workspace) |
| Bzlmod  | Disabled (--noenable_bzlmod)           |

### Rules

- Use rules_sh for shell tests (defined in WORKSPACE.bazel)
- Load from specific files: load("@rules_sh//shell:sh_test.bzl", "sh_test")

### Data Attributes

| Rule              | Description                                         |
| ----------------- | --------------------------------------------------- |
| Use direct labels | e.g., //config:all_configs                          |
| No glob()         | Never use glob() in data attributes                 |
| allow_empty=True  | Use for glob() in srcs where files might be missing |

---

## Infrastructure as Code

### Terraform

| Setting    | Details                                     |
| ---------- | ------------------------------------------- |
| Location   | infrastructure/terraform/                   |
| State      | Use moved blocks in main.tf for refactoring |
| Validation | Run via validate_terraform.sh               |

### Ansible

| Setting  | Details                                           |
| -------- | ------------------------------------------------- |
| Location | infrastructure/ansible/                           |
| Linting  | ansible_lint_wrapper.sh (skips if binary missing) |

---

## GitOps & Applications

### Manifests

Located in apps/.

### Domains

| Rule           | Description                                                     |
| -------------- | --------------------------------------------------------------- |
| NEVER hardcode | Do not hardcode domains (e.g. example.com) in Ingress manifests |
| Use templates  | Use templated references: {{ .Env.DOMAIN_BASE }}                |
| Validation     | validate_domain_config.sh enforces this                         |

---

## Documentation

### Location

docs/

### Structure

| Directory          | Purpose                           |
| ------------------ | --------------------------------- |
| docs/guides/       | User handbooks and runbooks       |
| docs/architecture/ | Design documents and decisions    |
| docs/reference/    | Service reference documentation   |
| docs/status/       | Reports and implementation status |

### Documentation Configuration

| Setting     | Details                                                    |
| ----------- | ---------------------------------------------------------- |
| Config      | \_config.yml uses toxicoder/materialistic-jekyll theme     |
| Links       | Internal links must be relative to the current file        |
| Link Target | Target .html files, not .md (e.g. ../guides/overview.html) |
| Diagrams    | Use Mermaid (.language-mermaid)                            |

---

## Testing & Verification

### Pre-Submission Checklist

Before submitting changes, run:

1. ./validate_config.sh — Verifies .env setup
2. ./validate_domain_config.sh — Checks for hardcoded domains
3. ./run_all_tests.sh — Runs the full suite (Bazel tests, infrastructure validation)

### Bazel Test Commands

```bash
# Run all tests
bazel test //tests/...

# Run specific test target
bazel test //tests/config:config_security_scan

# Run with verbose output
bazel test --test_output=errors //tests/...
```

bazel test --test_output=errors //tests/...
