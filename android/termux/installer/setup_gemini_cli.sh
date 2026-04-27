#!/data/data/com.termux/files/usr/bin/bash
set -e

# Storage permission (run once, opens dialog)
termux-setup-storage

pkg update -y && pkg upgrade -y

# Core packages
pkg install -y nodejs python git vim zip

# Workspace dirs
mkdir -p ~/workspace/mcp-servers
mkdir -p ~/storage/documents/termux/scripts

# uv (Python package manager)
pip install uv

# gemini-cli
npm install -g @google/gemini-cli

# Bitwarden CLI
npm install -g @bitwarden/cli

# notebooklm-mcp-cli
uv tool install notebooklm-mcp-cli
nlm login
nlm setup add gemini

# Bitwarden login (interactive)
bw login
