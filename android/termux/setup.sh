#!/data/data/com.termux/files/usr/bin/bash
# setup.sh - Main setup entry point for Termux
set -e

BASE_URL="https://raw.githubusercontent.com/hanato238/My_init_setting/main/android/termux"

# Download to a temp file and run so that stdin remains the terminal
# (curl | bash would otherwise block interactive prompts like bw login)
run_script() {
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/setup_XXXXXX.sh")
    curl -fsSL "$1" -o "$tmp"
    bash "$tmp"
    rm -f "$tmp"
}

echo "--- Starting Termux Environment Setup ---"

echo "[1/4] Installing LLM CLI and extensions..."
run_script "$BASE_URL/installer/install_llm_cli.sh"

echo "[2/4] Initializing Bitwarden security..."
run_script "$BASE_URL/installer/initialize_security.sh"

echo "[3/4] Setting up workspace..."
run_script "$BASE_URL/settings/set_workspace.sh"

echo "[4/4] Setting up aliases and profile..."
run_script "$BASE_URL/settings/set_aliases.sh"

echo "--- Setup Complete! ---"
echo "Please run 'source ~/.bash_profile' to apply changes."
