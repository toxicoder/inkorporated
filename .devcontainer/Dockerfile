FROM mcr.microsoft.com/devcontainers/base:jammy

# Install system tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    yamllint \
    clang-format \
    coreutils \
    python3-pip \
    curl \
    ca-certificates \
    gnupg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS) to support npm packages
# Using NodeSource to get a recent version required by tools like cline
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs

# Install global npm packages
RUN npm install -g eslint prettier cline

# Install Python tools
RUN pip3 install --no-cache-dir black flake8 yapf

# Install ArgoCD
RUN ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then \
         url="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"; \
       elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
         url="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-arm64"; \
       else \
         echo "Unsupported architecture: $ARCH" && exit 1; \
       fi \
    && curl -sSL -o /usr/local/bin/argocd "$url" \
    && chmod +x /usr/local/bin/argocd
