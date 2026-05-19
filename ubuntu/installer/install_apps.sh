#!/bin/bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script with sudo. Run as your regular user:" >&2
    echo "  bash ./installer/install_apps.sh" >&2
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
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg

# Python 3.12 (Deadsnakes PPA)
# Other versions can be installed later with: uv python install 3.x
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt-get update
sudo apt-get install -y python3.12

# Node.js v22 LTS via nvm (v20+ required for File Web API used by gemini-cli)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 22
nvm use 22
nvm alias default 22

# Cleanup
sudo apt-get autoremove -y

# uv (Python package/version manager)
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# Rust (rustup + cargo)
sudo snap install rustup --classic
rustup default stable

# Global npm tools
npm install -g @anthropic-ai/claude-code
npm install -g @google/gemini-cli
npm install -g @line/liff-cli

# GitHub CLI
sudo snap install gh --classic

# ngrok
sudo snap install ngrok

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
echo "  tmux:    tmux -V"
echo "  rust:    rustc --version"
echo "  node:    node --version"
echo "  claude:  claude --version"
echo "  gemini:  gemini --version"
echo "  uv:      uv --version"
echo "  gh:      gh --version"
echo "  liff:    liff-cli --help"
echo "  ngrok:   ngrok version"
echo "  docker:  docker --version"
echo "  compose: docker compose version"
