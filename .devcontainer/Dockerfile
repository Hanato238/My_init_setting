# My_init_setting 専用の開発コンテナ。汎用テンプレート（claude_container_template）とは別物。
# 方針: リポジトリと .git は編集できる（Orca の worktree 作成・commit はコンテナ内でも行う。push はホスト）。
# ホスト上で実行される設定（.claude/settings*・.mcp.json・.devcontainer）は docker-compose.yml で :ro に重ねる。
# 秘密情報は ANTHROPIC_API_KEY と repo 限定の GitHub PAT だけ。bws は入れない。
# ホストの Orca からは SSH（127.0.0.1:2222、鍵は `llm` が用意）で接続する。

# ---- 共通部分（issue #4 の claude-base と同じ内容）--------------------------------
# claude-base の公開後は、この区切りより上を `FROM ghcr.io/hanato238/claude-base:<YYYYMMDD>` に置き換え、
# 下の固有部分を `USER root` で始める。
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-slim

# bubblewrap / socat / ripgrep は Claude Code の Bash sandbox の依存。
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps curl ca-certificates gnupg jq git unzip ncurses-term \
    bubblewrap socat ripgrep \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 SHELL=/bin/bash DISABLE_AUTOUPDATER=1

# Zellij
ARG ZELLIJ_VERSION=0.41.2
RUN curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin \
    && chmod +x /usr/local/bin/zellij

# Claude Code（版を固定。コンテナ内では自動更新しない）
ARG CLAUDE_CODE_VERSION=2.1.301
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && node /usr/local/lib/node_modules/@anthropic-ai/claude-code/install.cjs
# ---- ここまで共通部分 --------------------------------------------------------------

# 検証ツール: shellcheck（ubuntu/・android/ の bash）、pwsh + Pester（windows/tests）。
# pwsh は 7 系なので、Windows PowerShell 5.1 固有の挙動と Windows 依存のテストはホストで確認する。
RUN apt-get update && apt-get install -y --no-install-recommends shellcheck \
    && curl -fsSL https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -o /tmp/ms-prod.deb \
    && dpkg -i /tmp/ms-prod.deb \
    && rm /tmp/ms-prod.deb \
    && apt-get update && apt-get install -y --no-install-recommends powershell \
    && rm -rf /var/lib/apt/lists/*
ARG PESTER_VERSION=5.7.1
RUN pwsh -NoProfile -Command "Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module Pester -RequiredVersion ${PESTER_VERSION} -Scope AllUsers -Force"

# GitHub 公式 MCP サーバー（外へ出る経路はこれだけ）。版を固定して入れる。
# 使うのはルートの .mcp.json の github エントリーで、managed-settings.json が github 以外を無効にする。
ARG GITHUB_MCP_VERSION=2.0.1
RUN curl -fsSL "https://github.com/github/github-mcp-server/releases/download/v${GITHUB_MCP_VERSION}/github-mcp-server_Linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin github-mcp-server \
    && chmod +x /usr/local/bin/github-mcp-server

# /workspace は uid の合わない bind mount なので、git の所有者チェックを外す。
RUN git config --system --add safe.directory '*'

# ホストの Orca（SSH worktrees）用の sshd。node ユーザーのまま 2222 番で動かす（start-sshd.sh が PID 1）。
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/*
COPY sshd_config /etc/ssh/sshd_devcontainer.conf
COPY --chmod=755 start-sshd.sh /usr/local/bin/start-sshd.sh
RUN mkdir -p /home/node/.ssh /home/node/.ssh-hostkeys /etc/devcontainer \
    && chown node:node /home/node/.ssh /home/node/.ssh-hostkeys
EXPOSE 2222

# 許可設定は .devcontainer/managed-settings.json を docker-compose.yml が
# /etc/claude-code/managed-settings.json に :ro でマウントする。
RUN mkdir -p /etc/claude-code

# Claude Code の認証・設定・メモリは名前付きボリューム（/workspace の外）に置く。
ENV CLAUDE_CONFIG_DIR=/home/node/.claude
RUN mkdir -p /home/node/.claude && chown -R node:node /home/node/.claude

WORKDIR /workspace
USER node
