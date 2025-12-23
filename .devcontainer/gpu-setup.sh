#!/bin/bash

# GPU Setup Script for Dev Container
# This script helps users configure GPU support when needed

echo "=== Dev Container GPU Setup Assistant ==="

# Check if nvidia-smi is available (indicating NVIDIA GPU support)
if command -v nvidia-smi &> /dev/null; then
    echo "✓ NVIDIA GPU detected"
    echo "Running nvidia-smi to check GPU status:"
    nvidia-smi
    echo ""
    echo "To enable GPU support in your dev container:"
    echo "1. Run: devcontainer up --workspace-folder . --run-args \"--gpus=all\""
    echo "2. Or manually start with: docker run --gpus=all -it <container-image>"
    echo ""
else
    echo "ℹ No NVIDIA GPU detected or nvidia-smi not available"
    echo "This is normal for Apple Silicon Macs and systems without NVIDIA GPUs"
    echo ""
    echo "Your container will work normally without GPU support."
    echo ""
    echo "If you have an NVIDIA GPU and need GPU support:"
    echo "1. Ensure NVIDIA drivers are properly installed"
    echo "2. Install nvidia-container-toolkit"
    echo "3. Run with: devcontainer up --workspace-folder . --run-args \"--gpus=all\""
fi

# Check architecture
ARCH=$(uname -m)
echo ""
echo "Current architecture: $ARCH"
if [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    echo "✓ Apple Silicon (ARM64) detected - optimized for M1/M2/M3 chips"
elif [[ "$ARCH" == "x86_64" ]]; then
    echo "✓ Intel/AMD (x86_64) detected - compatible with traditional CPUs"
else
    echo "ℹ Unknown architecture: $ARCH"
fi

echo ""
echo "=== Setup Complete ==="
echo "Your dev container is ready to use without GPU support."
echo "For GPU-enabled development, see the README.md in .devcontainer/"
