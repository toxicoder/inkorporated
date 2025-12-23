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

## Architecture Support

This container is designed to work across multiple architectures:
- **Apple Silicon (ARM64)**: Optimized for M1/M2/M3 chips
- **Intel/AMD (x86_64)**: Compatible with traditional CPUs
- **GPU Support**: Gracefully handles GPU configurations

## GPU Configuration

The container no longer automatically requests GPU access to prevent startup failures on systems without GPU drivers. 

### For GPU-enabled environments:
If you need GPU support, you can manually start the container with GPU access:
```bash
# Using Docker directly
docker run --gpus=all -it <container-image>

# Using Dev Containers with GPU support
devcontainer up --workspace-folder . --run-args "--gpus=all"
```

### For systems without GPUs:
The container will work normally without any additional configuration.

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
