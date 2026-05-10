#!/data/data/com.termux/files/usr/bin/bash
# install_llm_cli.sh - Install gemini-cli and extensions optimized for Termux
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS_DIR="$SCRIPT_DIR/../settings"

echo "--- Updating packages and installing dependencies ---"
pkg update -y
pkg install -y nodejs-lts python git vim zip uv jq

# Install CLIs
echo "--- Installing Gemini CLI ---"
npm install -g @google/gemini-cli

# Configure MCP servers from .mcp.json
echo "--- Configuring MCP servers for Gemini CLI ---"
if [ -f "$SETTINGS_DIR/set_mcp_repos.sh" ]; then
    bash "$SETTINGS_DIR/set_mcp_repos.sh" "$SETTINGS_DIR/.mcp.json"
else
    echo "Error: MCP configuration script not found at $SETTINGS_DIR/set_mcp_repos.sh"
    exit 1
fi

echo "LLM CLI environment setup complete."
