# Sovereign Workstation DevContainer
FROM mcr.microsoft.com/devcontainers/base:bullseye

# Install base tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        build-essential \
        curl \
        git \
        jq \
        tmux \
        unzip \
        vim \
        wget \
        ca-certificates \
        gnupg \
        lsb-release \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install b3sum for guardian drill merkle roots
RUN ARCH=$(dpkg --print-architecture) \
    && curl -Lo /tmp/b3sum.tar.gz \
       "https://github.com/BLAKE3-team/BLAKE3/releases/latest/download/b3sum_linux_${ARCH}_bin.tar.gz" \
    && tar -xzf /tmp/b3sum.tar.gz -C /usr/local/bin \
    && chmod +x /usr/local/bin/b3sum \
    && rm /tmp/b3sum.tar.gz

# Install yq (for parsing YAML config)
RUN VERSION=$(curl -sL https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r '.tag_name') \
    && BINARY=yq_linux_$(dpkg --print-architecture) \
    && wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O /usr/bin/yq \
    && chmod +x /usr/bin/yq

# Switch to non-root user
USER vscode

# Set up shell
RUN echo 'export PNPM_HOME="$HOME/.local/share/pnpm"' >> ~/.bashrc \
    && echo 'export PATH="$PNPM_HOME:$PATH"' >> ~/.bashrc

WORKDIR /workspace