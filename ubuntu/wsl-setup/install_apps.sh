#!/bin/bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script with sudo. Run as your regular user:" >&2
    echo "  bash ./wsl-setup/install_apps.sh" >&2
    exit 1
fi

LOG_FILE="$HOME/install_apps.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Install started: $(date) ==="

# --- systemd check (required for Docker service) ---
WSL_CONF="/etc/wsl.conf"
SYSTEMD_RUNNING=true

if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    SYSTEMD_RUNNING=false
    if ! grep -q "systemd=true" "$WSL_CONF" 2>/dev/null; then
        echo "Enabling systemd in $WSL_CONF..."
        if grep -q "\[boot\]" "$WSL_CONF" 2>/dev/null; then
            sudo sed -i '/\[boot\]/a systemd=true' "$WSL_CONF"
        else
            printf '\n[boot]\nsystemd=true\n' | sudo tee -a "$WSL_CONF" > /dev/null
        fi
    fi
    echo "Note: systemd is not running — Docker service setup will be skipped."
    echo "      After install, restart WSL (PowerShell: wsl --shutdown) and re-run this script."
fi

# Update and Upgrade
sudo apt-get update
sudo apt-get upgrade -y

# Latest git (git-core PPA): worktree.useRelativePaths below needs git >= 2.48,
# newer than what Ubuntu LTS ships.
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-get update

# Basic Tools
sudo apt-get install -y \
    git \
    curl \
    vim \
    tree \
    jq \
    wget \
    unzip \
    tmux \
    ripgrep \
    build-essential \
    ca-certificates \
    gnupg

# Node.js v22 LTS via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 22
nvm use 22
nvm alias default 22

# Cleanup
sudo apt-get autoremove -y

# uv (Python package/version manager; Python itself via: uv python install 3.x)
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# Claude Code (native installer -> ~/.local/bin/claude, self-updating)
if command -v claude &>/dev/null; then
    echo "OK: claude is already installed ($(claude --version 2>/dev/null || echo installed))"
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

# Antigravity CLI (-> ~/.local/bin/agy)
if command -v agy &>/dev/null; then
    echo "OK: Antigravity CLI (agy) is already installed"
else
    curl -fsSL https://antigravity.google/cli/install.sh | bash
fi

# GitHub CLI from the official apt repo. The snap's confinement breaks the git
# credential helper and access to paths outside $HOME.
if dpkg -s gh &>/dev/null; then
    echo "OK: $(gh --version | head -n1) is already installed"
else
    if command -v snap &>/dev/null && snap list gh &>/dev/null; then
        sudo snap remove gh
    fi
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -q
    sudo apt-get install -y gh
fi

if gh auth status &>/dev/null; then
    gh auth setup-git
    echo "OK: gh is authenticated and configured as git credential helper"
else
    echo "Note: gh is not authenticated yet. Run: gh auth login && gh auth setup-git"
fi

# --- Parallel worktrees (Orca) ---
# Each worktree runs its own claude/agy/dev server/watchers; the default
# inotify limits (128 instances) run out quickly with several in parallel.
INOTIFY_CONF="/etc/sysctl.d/99-inotify.conf"
if [ -f "$INOTIFY_CONF" ]; then
    echo "OK: $INOTIFY_CONF already exists"
else
    printf 'fs.inotify.max_user_watches = 524288\nfs.inotify.max_user_instances = 1024\n' \
        | sudo tee "$INOTIFY_CONF" > /dev/null
    sudo sysctl --system > /dev/null
    echo "OK: raised inotify limits ($INOTIFY_CONF)"
fi

# Relative worktree links keep working whether the repo is opened from WSL or
# from Windows via \\wsl$ (absolute links differ between the two).
git config --global worktree.useRelativePaths true
git config --global fetch.prune true

# --- Docker Engine (WSL2 native) ---
echo "=== Docker Engine setup ==="

# dpkg check avoids false positives from Docker Desktop's docker shim
if dpkg -s docker-ce &>/dev/null 2>&1; then
    echo "OK: $(docker --version) is already installed"
else
    echo "Installing Docker Engine..."

    sudo apt-get update -q
    sudo apt-get install -y ca-certificates curl

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -q
    sudo apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    echo "OK: $(docker --version)"
fi

# Add user to docker group
if ! groups "$USER" | grep -q '\bdocker\b'; then
    sudo usermod -aG docker "$USER"
    echo "Added $USER to docker group (takes effect on next login)"
else
    echo "OK: $USER is already in docker group"
fi

# Enable and start Docker service (requires systemd)
if "$SYSTEMD_RUNNING"; then
    if systemctl cat docker.service &>/dev/null; then
        sudo systemctl enable docker --quiet
        if ! systemctl is-active --quiet docker; then
            sudo systemctl start docker
        fi
        echo "OK: Docker service is running"
    else
        echo "Error: docker.service not found. Docker Engine installation may have failed." >&2
        exit 1
    fi
else
    echo "Skipped: Docker service not started (systemd unavailable)."
    echo "         Restart WSL, then re-run this script to complete Docker setup."
fi


echo ""
echo "=== Install finished: $(date) ==="
echo "Setup complete."
echo "  Restart your shell (or run: source ~/.bashrc) to reload PATH."
echo "  git:     git --version"
echo "  node:    node --version"
echo "  uv:      uv --version"
echo "  claude:  claude --version"
echo "  agy:     agy --version"
echo "  gh:      gh --version && gh auth status"
echo "  docker:  docker --version"
echo "  compose: docker compose version"
echo ""
echo "Orca (Windows): clone repos under ~/workspace (WSL ext4, not /mnt/c) and open"
printf '  \\\\wsl$\\%s\\home\\%s\\workspace\\<repo>  from Orca.\n' "${WSL_DISTRO_NAME:-Ubuntu}" "$USER"
