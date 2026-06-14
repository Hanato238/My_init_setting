FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    procps curl ca-certificates jq git unzip \
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

# claude-env: install + yazi（root）+ setup（HOME=/home/node）をひとつの RUN で実行
# npm install -g /local/path がシンボリックリンクを作る場合に備えて
# rm の前に setup まで完了させてから /tmp を削除する
ARG CLAUDE_ENV_REF=main
RUN curl -fsSL "https://api.github.com/repos/hanato238/My_init_setting/tarball/${CLAUDE_ENV_REF}" \
    | tar -xz --strip-components=1 -C /tmp \
    && npm install -g /tmp/packages/claude-env \
    && claude-env install \
    && HOME=/home/node claude-env setup \
    && chown -R node:node /home/node \
    && rm -rf /tmp/packages /tmp/windows /tmp/ubuntu /tmp/android /tmp/shared /tmp/claude_container

WORKDIR /workspace
USER node
