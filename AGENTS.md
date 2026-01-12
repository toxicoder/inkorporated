# Inkorporated Repository Agent Guide

This document outlines the rules, conventions, and operational procedures for agents (human and AI) working on the **Inkorporated** repository.

## 1. Project Overview

*   **Name:** `inkorporated` (or `toxicoder/inkorporated`).
*   **Architecture:** Hybrid Cloud.
    *   **Proxmox:** Persistent on-premises control plane.
    *   **AWS/GCP:** Ephemeral burst capacity.
*   **Core Tech Stack:** Bazel, Terraform, Ansible, Kubernetes (k3s), ArgoCD, Jekyll.

## 2. Environment Setup & Configuration

*   **Dev Container:** The project relies on the `.devcontainer` configuration. The environment is built from `.devcontainer/Dockerfile` (Ubuntu Jammy base) and includes Node.js, Python, and ArgoCD.
*   **Configuration Security:**
    *   The file `.devcontainer/.env` is the source of truth for secrets and environment-specific settings.
    *   **CRITICAL:** `.devcontainer/.env` MUST have file permissions set to `600` (`chmod 600 .devcontainer/.env`).
    *   Validation scripts (e.g., `tests/config/test_config_validation.sh`) will fail if permissions are incorrect.
    *   To set up: Copy `.devcontainer/.env.example` to `.devcontainer/.env`.
*   **Infrastructure Tools:** Scripts like `tests/config/validate_infrastructure.sh` will skip execution if tools (e.g., `pvecm`) are missing, to ensure CI compatibility.

## 3. Build System (Bazel)

*   **Mode:** Workspace mode is explicitly enabled (`common --enable_workspace`) and Bzlmod is disabled (`common --noenable_bzlmod`) in `.bazelrc`.
*   **Rules:**
    *   **Shell:** Use `rules_sh` (defined in `WORKSPACE.bazel`).
    *   **Loading Definitions:** You MUST load definitions from specific files (e.g., `load("@rules_sh//shell:sh_test.bzl", "sh_test")`). Do NOT assume a central `defs.bzl`.
*   **Data Attributes:**
    *   Use direct labels for `data` attributes (e.g., `//config:all_configs`).
    *   **Do NOT use `glob()`** directly on label lists in `data`.
    *   For glob usage in `srcs` (e.g., Ansible linting), set `allow_empty=True`.

## 4. Infrastructure as Code

### Terraform
*   **Location:** `infrastructure/terraform/`
*   **Structure:**
    *   Root `main.tf` manages provider-specific modules (`providers/{proxmox,aws,gcp}`).
    *   **State Migration:** Use `moved` blocks in `main.tf` to preserve resource state during refactoring.
*   **Validation:**
    *   Tests run via Bazel `sh_test` targets calling `validate_terraform.sh` and `check_fmt.sh`.
    *   These scripts rely on the `terraform` binary being available.

### Ansible
*   **Location:** `infrastructure/ansible/`
*   **Inventory:** Segments hosts into:
    *   `proxmox_vms`
    *   `proxmox_lxc`
    *   `cloud_nodes`
*   **Roles:** Use the `cloud-join` role for remote nodes.
*   **Linting:** `ansible_lint_wrapper.sh` runs via Bazel but exits 0 (skips) if `ansible-lint` is missing.

## 5. Documentation

*   **Location:** `docs/`
*   **Engine:** Jekyll with `toxicoder/materialistic-jekyll` remote theme.
*   **Configuration (`docs/_config.yml`):**
    *   `url`: `https://toxicoder.github.io`
    *   `baseurl`: `/inkorporated`
    *   `repository`: `toxicoder/inkorporated`
    *   Required Plugins: `jekyll-seo-tag`, `jekyll-feed`.
*   **Content Rules:**
    *   **Links:** Internal links must be **relative** and point to `.html` files (e.g., `guides/overview.html`), not `.md` and not absolute paths.
    *   **Project Name:** Refer to the project as **Inkorporated**. Replace legacy references to `inkorporated-k8s-apps`.
    *   **Mermaid:** Diagrams are supported via `docs/assets/js/mermaid-support.js`. Use `.language-mermaid` code blocks.
    *   **Assets:** Navigation links in `docs/_data/navigation.yml` are absolute (starting with `/`).

## 6. Testing & Verification

*   **Main Entrypoint:** `./run_all_tests.sh` runs the full suite.
*   **Configuration Validation:** `./validate_config.sh` and `./validate_domain_config.sh`.
*   **Security Scanning:**
    *   Run via `//tests/config:config_security_scan` (calls `scan_secrets.sh`).
    *   **Exclusions:** Explicitly excludes `.git`, `node_modules`, `_site`, `.terraform`.
*   **Frontend/Docs:** GitHub Pages deployment is handled manually via `git worktree` to the `gh-pages` branch.

## 7. Development Workflow

1.  **Modify Source:** Edit files in `src/`, `infrastructure/`, `docs/`, etc.
2.  **Verify:** Run relevant validation scripts or Bazel tests.
3.  **Pre-Commit:** Ensure all tests pass.
4.  **Submit:** Commit with descriptive messages.
