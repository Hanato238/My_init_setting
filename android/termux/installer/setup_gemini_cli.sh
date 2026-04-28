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

# install gemini-cli-termux
npm install -g @mmmbuto/gemini-cli-termux@latest


# add context7
gemini extensions install https://github.com/upstash/context7

# add desktop-commander
gemini extensions install　https://github.com/wonderwhy-er/DesktopCommanderMCP

# add github
gemini extensions install https://github.com/amelianoir/github-mcp-server

# add google-workspace
gemini extensions install https://github.com/gemini-cli-extensions/workspace


gemini extensions install https://github.com/gemini-cli-extensions/clasp