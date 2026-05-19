#!/bin/bash
set -e

LOG_FILE="$HOME/install_apps.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Install started: $(date) ==="

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

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# Global npm tools
npm install -g @anthropic-ai/claude-code
npm install -g @google/gemini-cli

# GitHub CLI
sudo snap install gh --classic

echo "=== Install finished: $(date) ==="
echo "Setup complete."
echo "  Restart your shell (or run: source ~/.bashrc) to reload PATH."
echo "  tmux:   tmux -V"
echo "  rust:   rustc --version"
echo "  node:   node --version"
echo "  claude: claude --version"
echo "  gemini: gemini --version"
echo "  uv:     uv --version"
echo "  gh:     gh --version"
