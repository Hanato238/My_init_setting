#!/data/data/com.termux/files/usr/bin/bash
# install_llm_cli.sh - Install Antigravity CLI and its dependencies for Termux
set -e

echo "--- Updating packages and installing dependencies ---"
pkg update -y
pkg install -y nodejs-lts git jq uv openssh

echo "--- Installing Antigravity CLI ---"
if command -v agy &>/dev/null; then
    echo "Antigravity CLI (agy) is already installed."
else
    curl -fsSL https://antigravity.google/cli/install.sh | bash
fi

echo "LLM CLI environment setup complete."
