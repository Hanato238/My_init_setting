#!/bin/bash
# setup_nanoclaw.sh - Setup NanoClaw on Ubuntu

# Add Telegram API IP to /etc/hosts on WSL2
if grep -qiE "microsoft|WSL" /proc/version 2>/dev/null; then
    if ! grep -q "api.telegram.org" /etc/hosts; then
        echo "149.154.166.110 api.telegram.org" | sudo tee -a /etc/hosts
    fi
fi

# Update and install basic dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential curl git wget default-jre openjdk-17-jre 


# Install NVM if not already installed
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
fi

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js (NanoClaw recommends v20+)
nvm install 24
nvm use 24

# Install pnpm (required by NanoClaw)
npm install -g pnpm

# Install Claude Code CLI
curl -fsSL https://claude.ai/install.sh | bash

# Create workspace directory if it doesn't exist
mkdir -p "$HOME/workspace"
cd "$HOME/workspace" || exit

# Clone NanoClaw repository
if [ ! -d "nanoclaw" ]; then
    git clone https://github.com/qwibitai/nanoclaw
fi
cd ./nanoclaw || exit

# Run the NanoClaw setup script
# This script will guide you through Anthropic API key setup and channel pairing.
bash nanoclaw.sh
