#!/data/data/com.termux/files/usr/bin/bash
# install_llm_cli.sh - Install Antigravity CLI and its dependencies (Termux or Debian/Ubuntu)
set -e

echo "--- Updating packages and installing dependencies ---"
if command -v pkg &>/dev/null; then
    pkg update -y
    pkg install -y nodejs-lts git jq uv openssh
else
    apt-get update -y
    apt-get install -y nodejs npm git jq curl ca-certificates openssh-client
    if ! command -v uv &>/dev/null; then
        echo "--- Installing uv ---"
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

echo "--- Installing Antigravity CLI ---"
if command -v agy &>/dev/null; then
    echo "Antigravity CLI (agy) is already installed."
else
    curl -fsSL https://antigravity.google/cli/install.sh | bash
fi

echo "LLM CLI environment setup complete."
