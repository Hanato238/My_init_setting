# 共通部分（OS・基本 apt・zellij・Claude Code・LANG/SHELL・Orca 用の鍵なし sshd）は claude-base に入っている
# （base_image/Dockerfile）。ここではテンプレート固有の差分だけを足す。base は USER node で終わるので
# root に切り替えてから追加する。base を試すときは --build-arg BASE_IMAGE=ghcr.io/hanato238/claude-base:local で差し替える。
# API キーは docker-compose.yml の environment: だけが供給する（イメージには入れない）。
ARG BASE_IMAGE=ghcr.io/hanato238/claude-base:20261016
FROM ${BASE_IMAGE}

USER root

# uv（mcp-server-fetch / mcp-server-git 用）
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Antigravity CLI (agy)
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash \
    && mv /root/.local/bin/agy /usr/local/bin/agy

# gws (Google Workspace CLI)
RUN npm install -g @googleworkspace/cli

# Google Cloud SDK (gcloud)
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# notebooklm-mcp-cli (uv tool) - redirect the install to a shared location
# instead of root's home, same reasoning as ubuntu/remote-agy/setup.sh
RUN UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin uv tool install notebooklm-mcp-cli

# claude-env: ローカルパッケージを COPY して install + setup
COPY packages/claude-env /tmp/claude-env
RUN npm install -g /tmp/claude-env \
    && claude-env install \
    && HOME=/home/node claude-env setup \
    && chown -R node:node /home/node \
    && rm -rf /tmp/claude-env

WORKDIR /workspace
USER node
