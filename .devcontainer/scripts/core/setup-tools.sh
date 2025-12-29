#!/bin/bash
# Install development tools and dependencies

# Install system tools
echo "Installing system tools..."
sudo apt-get update
sudo apt-get install -y coreutils findutils yamllint clang-format

# Install Node.js tools
echo "Installing Node.js tools..."
npm install -g eslint prettier cline

# Install Python tools (skip if pip3 not available)
echo "Installing Python tools..."
if command -v pip3 &> /dev/null; then
    pip3 install black flake8 yapf
else
    echo "pip3 not found, skipping Python tool installation"
fi

# Install ArgoCD
echo "Installing ArgoCD..."
arch=$(uname -m)
if [ "$arch" = "x86_64" ]; then
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-arm64
else
    echo "Unsupported architecture: $arch"
    exit 1
fi
sudo mv /tmp/argocd /usr/local/bin/argocd
sudo chmod +x /usr/local/bin/argocd

echo "ArgoCD installation complete."