# Claude Code 用 devcontainer の共通ベース（ghcr.io/hanato238/claude-base）。
# 中身は共通部分（Claude Code・agy・zellij）と、ホストの Orca から入るための鍵なし sshd（下の sshd の節を参照）。
# uv / gws / gcloud / MCP サーバー / safe.directory は下流で足す。
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

# Antigravity CLI (agy)
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash \
    && mv /root/.local/bin/agy /usr/local/bin/agy

# ホストの Orca（SSH worktrees）用の sshd。node ユーザーのまま 2222 番で動かす（CMD の start-sshd.sh が PID 1）。
# 鍵は使わず node の空パスワードで入る。下流は ports を必ず 127.0.0.1 にだけ公開すること
# （例: "127.0.0.1:${SSH_PORT:-}:2222"。SSH_PORT はホストの llm 関数が割り当てる）。
# sshd を使わない下流は compose で command（例: sleep infinity）を指定すれば起動しない。
# sshd は node 権限で /etc/shadow を読めないので、空パスワードは /etc/passwd 側に置き、shadow の行は消す。
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i 's/^node:x:/node::/' /etc/passwd \
    && sed -i '/^node:/d' /etc/shadow
COPY sshd_config /etc/ssh/sshd_devcontainer.conf
COPY --chmod=755 start-sshd.sh /usr/local/bin/start-sshd.sh
RUN mkdir -p /home/node/.ssh && chown node:node /home/node/.ssh
EXPOSE 2222

WORKDIR /workspace
USER node
CMD ["/usr/local/bin/start-sshd.sh"]
