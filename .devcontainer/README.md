# Developer Container

This directory contains the configuration for the generalized developer container that provides a consistent development environment for this project.

## Features

The dev container includes:
- **Base Image**: Universal Linux container from Microsoft
- **Development Tools**:
  - Ansible
  - Terraform with tflint and terragrunt
  - Kubernetes, Helm, and Minikube tools
- **IDE Extensions**:
  - Claude Dev (Cline AI coding assistant)
- **Post-creation Setup**:
  - Installs Cline globally
  - Installs Argo CD CLI

## Usage

1. Open this project in VS Code with Dev Containers extension
2. The container will automatically build and start
3. All development tools are pre-installed and configured
4. The Cline AI assistant is ready to help with coding tasks

## Customization

To customize this container for your specific project needs:
1. Modify `devcontainer.json` to add/remove features
2. Update `postCreateCommand` to install additional tools
3. Adjust VS Code extensions as needed
