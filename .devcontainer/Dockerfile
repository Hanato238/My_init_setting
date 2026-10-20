# My_init_setting 専用の開発コンテナ。汎用テンプレート（claude_container_template）とは別物。
# 方針: リポジトリと .git は編集できる（Orca の worktree 作成・commit はコンテナ内でも行う。push はホスト）。
# ホスト上で実行される設定（.claude/settings*・.mcp.json・.devcontainer）は docker-compose.yml で :ro に重ねる。
# 秘密情報は ANTHROPIC_API_KEY・ANTIGRAVITY_API_KEY と repo 限定の GitHub PAT だけ。
#
# 共通部分（OS・基本 apt・zellij・Claude Code・agy・Orca 用の鍵なし sshd）は claude-base に入っている
# （base_image/Dockerfile）。base を試すときは --build-arg BASE_IMAGE=ghcr.io/hanato238/claude-base:local で差し替える。
ARG BASE_IMAGE=ghcr.io/hanato238/claude-base:20261020
FROM ${BASE_IMAGE}

USER root

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

# 許可設定は .devcontainer/managed-settings.json を docker-compose.yml が
# /etc/claude-code/managed-settings.json に :ro でマウントする。
RUN mkdir -p /etc/claude-code

# Claude Code の認証・設定・メモリは名前付きボリューム（/workspace の外）に置く。
ENV CLAUDE_CONFIG_DIR=/home/node/.claude
RUN mkdir -p /home/node/.claude && chown -R node:node /home/node/.claude

WORKDIR /workspace
USER node
