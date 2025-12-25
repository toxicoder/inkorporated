#!/bin/bash
# Setup additional dev container tools

echo "Installing additional tools for file management..."
sudo apt-get update
sudo apt-get install -y coreutils findutils

echo "Adding vscode user to appropriate groups..."
sudo usermod -aG vscode $(whoami)

echo "Installing Node.js linting and formatting tools..."
# Install common linting and formatting tools globally
npm install -g eslint prettier

echo "Installing Python linting and formatting tools..."
# Install Python tools for linting and formatting
pip install black flake8 yapf

echo "Installing YAML linting tools..."
# Install YAML linting tools
sudo apt-get install -y yamllint

echo "Installing other language formatting tools..."
# Install clang-format for C/C++ (if needed)
sudo apt-get install -y clang-format

echo "Installing Argo CD..."
arch=$(uname -m)
if [ "$arch" = "x86_64" ]; then
    echo "Downloading Argo CD for x86_64..."
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
    echo "Downloading Argo CD for ARM64..."
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-arm64
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

echo "Moving Argo CD to /usr/local/bin..."
sudo mv /tmp/argocd /usr/local/bin/argocd

echo "Setting execute permissions..."
sudo chmod +x /usr/local/bin/argocd

echo "Argo CD installation complete."
