FROM ubuntu:24.04

# Install prerequisites: git, curl, Node.js 22, Python 3.11
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    git curl xz-utils ca-certificates gnupg \
    python3 python3-pip python3-venv \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 (for MCP servers)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Create test user (non-root, mirrors real install)
RUN useradd -m -s /bin/bash rudr9
USER rudr9
WORKDIR /home/rudr9

# Install Hermes Agent
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-browser

# Copy RUDR9 project
COPY --chown=rudr9:rudr9 . /home/rudr9/RUDR9

# Default: bash (interactive testing)
CMD ["bash"]