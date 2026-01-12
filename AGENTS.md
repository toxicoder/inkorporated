# Inkorporated Repository Agent Guide

This document outlines the authoritative rules, conventions, and operational procedures for agents (human and AI) working on the **Inkorporated** repository.

## 1. Project Overview

*   **Name:** `inkorporated` (or `toxicoder/inkorporated`).
*   **Architecture:** Hybrid Cloud.
    *   **Proxmox:** Persistent on-premises control plane.
    *   **AWS/GCP:** Ephemeral burst capacity.
*   **Core Tech Stack:** Bazel, Terraform, Ansible, Kubernetes (k3s), ArgoCD, Jekyll.

## 2. Environment Setup & Configuration

*   **Dev Container:** The project relies on the `.devcontainer` configuration.
*   **Secrets & Settings:**
    *   **Source of Truth:** `.devcontainer/.env`.
    *   **Security:** File permissions **MUST** be set to `600` (`chmod 600 .devcontainer/.env`).
    *   **Validation:** `validate_config.sh` checks for permissions and required MCP variables (e.g., `GH_TOKEN`, `PERPLEXITY_API_KEY`).
    *   **Setup:** Copy `.devcontainer/.env.example` to `.devcontainer/.env`.
*   **Environments:**
    *   Configuration is split by environment (dev, staging, prod) in `config/environments/`.
    *   Application overrides are in `apps/environments/`.

## 3. Directory Structure

*   `apps/`: GitOps manifests (ArgoCD Applications, ApplicationSets).
    *   `apps/shared/`: Base manifests.
    *   `apps/environments/`: Environment-specific overlays.
*   `config/`: Global and environment-specific configuration files.
*   `docs/`: Jekyll-based documentation.
*   `infrastructure/`:
    *   `terraform/`: Infrastructure provisioning (Proxmox, AWS, GCP).
    *   `ansible/`: Configuration management (k3s installation).
*   `tests/`: Validation scripts and Bazel test targets.

## 4. Build System (Bazel)

*   **Mode:** Workspace enabled (`common --enable_workspace`), Bzlmod disabled (`common --noenable_bzlmod`).
*   **Rules:**
    *   Use `rules_sh` for shell tests (defined in `WORKSPACE.bazel`).
    *   Load from specific files: `load("@rules_sh//shell:sh_test.bzl", "sh_test")`.
*   **Data Attributes:**
    *   Use direct labels (e.g., `//config:all_configs`).
    *   **No `glob()`** in `data` attributes.
    *   Use `allow_empty=True` for `glob()` in `srcs` where files might be missing.

## 5. Infrastructure as Code

### Terraform
*   **Location:** `infrastructure/terraform/`.
*   **State:** Use `moved` blocks in `main.tf` for refactoring.
*   **Validation:** Run via `validate_terraform.sh`.

### Ansible
*   **Location:** `infrastructure/ansible/`.
*   **Linting:** `ansible_lint_wrapper.sh` (skips if binary missing).

## 6. GitOps & Applications

*   **Manifests:** Located in `apps/`.
*   **Domains:**
    *   **NEVER** hardcode domains (e.g., `example.com`) in Ingress manifests.
    *   Use templated references: `{{ .Env.DOMAIN_BASE }}`.
    *   Validation: `validate_domain_config.sh` enforces this.

## 7. Documentation

*   **Location:** `docs/`.
*   **Structure:**
    *   `docs/guides/`: User handbooks and runbooks.
    *   `docs/architecture/`: Design documents and decisions.
    *   `docs/reference/`: Service reference documentation.
    *   `docs/status/`: Reports and implementation status.
*   **Config:** `_config.yml` uses `toxicoder/materialistic-jekyll` theme.
*   **Links:**
    *   Internal links must be **relative** to the current file.
    *   Target `.html` files, not `.md` (e.g., `../guides/overview.html`).
*   **Diagrams:** Use Mermaid (`.language-mermaid`).

## 8. Verification & Testing

Before submitting changes, run:

1.  **`./validate_config.sh`**: Verifies `.env` setup.
2.  **`./validate_domain_config.sh`**: Checks for hardcoded domains.
3.  **`./run_all_tests.sh`**: Runs the full suite (Bazel tests, infrastructure validation).

## 9. MCP & AI Integration

*   This repository is designed to work with MCP (Model Context Protocol).
*   **Configuration:** MCP settings are in `cline_mcp_settings.json` (general) and `.devcontainer/.env` (secrets).
*   **Security:** `scan_secrets.sh` is used to prevent secret leakage. Run `//tests/config:config_security_scan`.
