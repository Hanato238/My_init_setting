FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    procps curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Zellij
ARG ZELLIJ_VERSION=0.41.2
RUN curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin \
    && chmod +x /usr/local/bin/zellij

# uv（mcp-server-fetch / mcp-server-git 用）
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Claude Code + Gemini CLI
RUN npm install -g @anthropic-ai/claude-code @google/gemini-cli

# zellij: claude を自動起動するレイアウト
RUN mkdir -p /home/node/.config/zellij/layouts && \
    echo 'default_layout "claude"' > /home/node/.config/zellij/config.kdl && \
    chown -R node:node /home/node/.config
COPY --chown=node:node .devcontainer/zellij-layout.kdl /home/node/.config/zellij/layouts/claude.kdl

WORKDIR /workspace
USER node
