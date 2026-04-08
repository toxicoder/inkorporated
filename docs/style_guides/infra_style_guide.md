# Infrastructure Style Guide

## Overview

This guide outlines the coding standards and best practices for Terraform and
Ansible infrastructure-as-code in the Inkorporated project.

## Terraform Guidelines

### File Organization

```
terraform/
├── main.tf          - Root module resources
├── variables.tf     - Input variables
├── outputs.tf       - Output values
├── providers.tf     - Provider configurations
├── terraform.tfvars - Local configuration
├── modules/         - Reusable modules
└── profiles/        - Environment profiles
```

### Naming Conventions

- Resources: `type_name_suffix` (e.g., `aws_instance_web_server`)
- Variables: `component_type_attribute`
- Locals: Same as variables

### Best Practices

1. Use `moved` blocks for refactoring
2. Enable terraform formatting with `terraform fmt -check`
3. Run validation with `./validate_terraform.sh`

## Ansible Guidelines

### Directory Structure

```
ansible/
├── ansible.cfg      - Configuration
├── inventory/       - Host inventories
├── playbooks/       - Playbook definitions
└── roles/           - Reusable roles
```

### Linting

Run `./ansible_lint_wrapper.sh` for linting (skips if binary missing).

### Best Practices

1. Use named templates for clarity
2. Keep playbooks minimal, delegate to roles
3. Document roles with README files
