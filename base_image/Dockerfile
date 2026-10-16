# Claude Code 用 devcontainer の共通ベース（ghcr.io/hanato238/claude-base）。
# 中身は共通部分だけ。uv / agy / gws / bws / gcloud / MCP サーバー / 秘密情報 / safe.directory は下流で足す。
# 下流は FROM したあと、追加は USER root で行い、最後に USER node に戻す。
# 版は ARG で固定し、Renovate が「# renovate:」の行を手がかりに更新 PR を作る。

# renovate: datasource=docker depName=node
ARG NODE_VERSION=22.23.3
FROM node:${NODE_VERSION}-slim

# bubblewrap / socat / ripgrep は Claude Code の Bash sandbox の依存。
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps curl ca-certificates gnupg jq git unzip ncurses-term \
    bubblewrap socat ripgrep \
    && rm -rf /var/lib/apt/lists/*

# コンテナ内での自動更新は無効。Claude Code の版を上げるのはイメージの更新だけ。
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 SHELL=/bin/bash DISABLE_AUTOUPDATER=1

# Zellij
# renovate: datasource=github-releases depName=zellij-org/zellij
ARG ZELLIJ_VERSION=0.45.1
RUN curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin \
    && chmod +x /usr/local/bin/zellij

# Claude Code
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.301
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && node /usr/local/lib/node_modules/@anthropic-ai/claude-code/install.cjs

WORKDIR /workspace
USER node
