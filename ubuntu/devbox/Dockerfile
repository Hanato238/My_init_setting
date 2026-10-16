# devbox image: tmux + Claude Code + Antigravity CLI (agy) + Google Chrome
# development container, built/run by ./setup.sh on the WSL host's Docker
# Engine. Chrome is included so GUI-dependent CLI logins (planned:
# nlm-login/gws-login, once notebooklm-mcp-cli/gws are installed) can run
# *inside* this container, displayed on the Windows desktop via WSLg socket
# passthrough - see setup.sh's GUI_DOCKER_ARGS and README.md. This replaces
# the Windows+PowerShell host-browser-orchestration design (CDP proxy /
# docker cp of credentials) used by claude_container_template/.devcontainer/:
# with WSLg, the browser can just run where the CLI runs.
#
# Package lists live under packages/ (one file per package manager,
# mirroring windows/installer/packages/) instead of being inlined here.
#
# Scope: this image only provides the tools. Persistence (so sessions survive
# `docker stop`/WSL restarts) comes from setup.sh mounting a named volume at
# $HOME and bind-mounting the project repo - see setup.sh and README.md.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Bash arrays are used for the package lists below (consistent with every
# other packages.sh in this repo) - /bin/sh (dash, Ubuntu's default RUN
# shell) can't parse that syntax, so switch RUN's shell to bash for the rest
# of this file.
SHELL ["/bin/bash", "-c"]

COPY packages/ /tmp/packages/

# Google Chrome's own apt repo (needed before packages/apt-packages.sh's
# google-chrome-stable entry can be installed below) - same signed-by /
# sources.list.d pattern as the Docker/gcloud apt repos in
# ubuntu/wsl-setup/install_apps.sh and ubuntu/remote-agy/setup.sh.
RUN apt-get update && apt-get install -y --no-install-recommends curl gnupg ca-certificates \
    && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && . /tmp/packages/apt-packages.sh \
    && apt-get install -y --no-install-recommends "${DEVBOX_APT_PACKAGES[@]}" \
    && rm -rf /var/lib/apt/lists/*

ARG USERNAME=dev
RUN useradd -m -s /bin/bash "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME
ENV HOME=/home/$USERNAME
WORKDIR $HOME

# Node.js (nvm) - required by the npm-based Claude Code install below.
ENV NVM_DIR=$HOME/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install 22 \
    && nvm alias default 22

# Claude Code (npm global, same package as ubuntu/wsl-setup/install_apps.sh)
RUN . "$NVM_DIR/nvm.sh" \
    && . /tmp/packages/npm-packages.sh \
    && npm install -g "${DEVBOX_NPM_PACKAGES[@]}"

# Antigravity CLI (agy) - official installer, same as
# ubuntu/remote-agy/setup.sh. Drops the binary under $HOME/.local/bin.
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

ENV PATH="$HOME/.local/bin:$PATH"

# Keep the container alive so setup.sh can `docker exec` into it repeatedly
# (tmux, claude, agy, google-chrome are all run via exec, not as the
# container's main process - that way the container's own lifecycle doesn't
# depend on any one of them staying open).
CMD ["sleep", "infinity"]
