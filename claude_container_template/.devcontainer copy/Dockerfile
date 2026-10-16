# 俯瞰コンテナ（workspace 専用）。汎用テンプレート（My_init_setting/claude_container_template）とは別物。
# 方針: 子プロジェクトは読むだけ・秘密情報は 3 種だけ・bws / gws / gcloud は入れない。
FROM node:22-slim

# bubblewrap / socat / ripgrep は Claude Code の Bash sandbox の依存。
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps curl ca-certificates gnupg jq git ncurses-term \
    bubblewrap socat ripgrep \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 SHELL=/bin/bash

# Zellij
ARG ZELLIJ_VERSION=0.41.2
RUN curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin \
    && chmod +x /usr/local/bin/zellij

# MCP サーバー（外へ出る経路はこの 2 つだけ）。起動のたびに最新版を取らないよう、版を固定して入れる。
# GitHub 公式 MCP サーバー。有効にするツールは .mcp.json の GITHUB_TOOLS で絞る。
ARG GITHUB_MCP_VERSION=2.0.1
RUN curl -fsSL "https://github.com/github/github-mcp-server/releases/download/v${GITHUB_MCP_VERSION}/github-mcp-server_Linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin github-mcp-server \
    && chmod +x /usr/local/bin/github-mcp-server
# Todoist MCP
ARG TODOIST_MCP_VERSION=13.4.1
RUN npm install -g "@doist/todoist-mcp@${TODOIST_MCP_VERSION}"

# Claude Code
RUN npm install -g @anthropic-ai/claude-code \
    && node /usr/local/lib/node_modules/@anthropic-ai/claude-code/install.cjs

# /workspace は root 所有の bind mount（uid 不一致）なので、git の所有者チェックを外す。
# .git は :ro でマウントされるため、index の更新を伴うロックも取らせない。
RUN git config --system --add safe.directory '*'
ENV GIT_OPTIONAL_LOCKS=0

# 許可設定の正本は /workspace/.claude/settings.json の 1 ファイル。
# docker-compose.yml がそれを /etc/claude-code/managed-settings.json にも :ro でマウントし、
# managed settings として効かせる（ユーザー設定では緩められず、ルール変更に再ビルドも要らない）。
RUN mkdir -p /etc/claude-code

# Claude Code の認証・設定・メモリは名前付きボリューム（/workspace の外）に置く。
ENV CLAUDE_CONFIG_DIR=/home/node/.claude
RUN mkdir -p /home/node/.claude && chown -R node:node /home/node/.claude

WORKDIR /workspace
USER node
