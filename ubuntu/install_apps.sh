#!/bin/bash
set -e

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
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    fail2ban

# Python (Deadsnakes PPA for multiple versions)
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt-get update
sudo apt-get install -y python3.9 python3.10 python3.11 python3.12 python3.13

# uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Node.js (LTS)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Cleanup
sudo apt-get autoremove -y

# Enable and start fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

echo "Apps installation and security setup complete."
