#!/bin/bash

echo "Testing post-create commands..."

# Test npm install -g cline
echo "Running: npm install -g cline || echo 'Cline may already be installed'"
npm install -g cline || echo 'Cline may already be installed'

# Test arch detection and argocd download
echo "Detecting architecture..."
arch=$(uname -m)
echo "Architecture detected: $arch"

if [ "$arch" = "x86_64" ]; then
    echo "Downloading argocd for x86_64..."
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
    echo "Downloading argocd for ARM64..."
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-arm64
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

echo "Making argocd executable..."
chmod +x /tmp/argocd
echo "Test completed successfully!"
