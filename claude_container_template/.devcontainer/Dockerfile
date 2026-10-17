# 共通部分（OS・基本 apt・zellij・Claude Code・LANG/SHELL）は claude-base に入っている（base_image/Dockerfile）。
# ここではテンプレート固有の差分だけを足す。base は USER node で終わるので root に切り替えてから追加する。
FROM ghcr.io/hanato238/claude-base:20261016

USER root

# uv（mcp-server-fetch / mcp-server-git 用）
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Antigravity CLI (agy)
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash \
    && mv /root/.local/bin/agy /usr/local/bin/agy

# gws (Google Workspace CLI)
RUN npm install -g @googleworkspace/cli

# bws (Bitwarden Secrets Manager CLI) - prebuilt musl binary
ARG BWS_VERSION=2.1.0
RUN curl -fsSL "https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}/bws-x86_64-unknown-linux-musl-${BWS_VERSION}.zip" -o /tmp/bws.zip \
    && unzip -q /tmp/bws.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/bws \
    && rm /tmp/bws.zip

# bws のアクセストークンはコンテナ内 ~/.config/bws/access-token に保存し
# (.devcontainer/bws-login.sh が書き込む)、シェル起動時に BWS_ACCESS_TOKEN として読み込む。
RUN printf '%s\n' \
      '# bws access token (.devcontainer/bws-login.sh がコンテナ内に保存する)' \
      'if [ -r "$HOME/.config/bws/access-token" ]; then' \
      '  export BWS_ACCESS_TOKEN="$(cat "$HOME/.config/bws/access-token")"' \
      'fi' \
      > /etc/profile.d/bws.sh \
    && chmod 644 /etc/profile.d/bws.sh \
    && printf '\n%s\n' '[ -r /etc/profile.d/bws.sh ] && . /etc/profile.d/bws.sh' >> /etc/bash.bashrc

# API キーは secrets.list の許可リストに従い .devcontainer/load-secrets.sh が
# ~/.secrets (chmod 600) へ書き込む。ここではそれをシェル起動時に読み込むだけ。
RUN printf '%s\n' \
      '# API keys (.devcontainer/load-secrets.sh が ~/.secrets に書く)' \
      '[ -r "$HOME/.secrets" ] && . "$HOME/.secrets"' \
      > /etc/profile.d/secrets.sh \
    && chmod 644 /etc/profile.d/secrets.sh \
    && printf '\n%s\n' '[ -r /etc/profile.d/secrets.sh ] && . /etc/profile.d/secrets.sh' >> /etc/bash.bashrc

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
