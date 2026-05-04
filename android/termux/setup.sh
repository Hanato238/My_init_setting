#!/data/data/com.termux/files/usr/bin/bash
# setup.sh - Main setup entry point for Termux
set -e

# Base URL for bootstrap (GitHub)
BASE_URL="https://raw.githubusercontent.com/hanato238/My_init_setting/main/android/termux"

echo "--- Starting Termux Environment Setup ---"

# 1. Install LLM CLI & Extensions (URL bootstrap)
echo "[1/4] Installing LLM CLI and extensions..."
curl -fsSL "$BASE_URL/installer/install_llm_cli.sh" | bash

# 2. Initialize Security (URL bootstrap)
echo "[2/4] Initializing Bitwarden security..."
curl -fsSL "$BASE_URL/installer/initialize_security.sh" | bash

# 3. Setup Workspace
echo "[3/4] Setting up workspace..."
# After step 1, the repo should be cloned if using local files is preferred,
# but for the first run, we use the URL.
curl -fsSL "$BASE_URL/settings/set_workspace.sh" | bash

# 4. Set Aliases
echo "[4/4] Setting up aliases and profile..."
curl -fsSL "$BASE_URL/settings/set_aliases.sh" | bash

echo "--- Setup Complete! ---"
echo "Please run 'source ~/.bash_profile' to apply changes."
