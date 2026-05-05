#!/data/data/com.termux/files/usr/bin/bash
# setup.sh - Main setup entry point for Termux
set -e

BASE_URL="https://raw.githubusercontent.com/hanato238/My_init_setting/main/android/termux"

# Function to run scripts locally if available, otherwise download
run_task() {
    local script_rel_path="$1"
    local script_url="$BASE_URL/$script_rel_path"
    local local_script="$(dirname "$0")/$script_rel_path"

    if [ -f "$local_script" ]; then
        echo "--- Running local script: $script_rel_path ---"
        bash "$local_script"
    else
        echo "--- Downloading and running: $script_rel_path ---"
        local tmp
        tmp=$(mktemp "${TMPDIR:-/tmp}/setup_XXXXXX.sh")
        curl -fsSL "$script_url" -o "$tmp"
        bash "$tmp"
        rm -f "$tmp"
    fi
}

echo "--- Starting Termux Environment Setup ---"

if [ ! -d "$HOME/workspace" ]; then
    mkdir -p "$HOME/workspace"
    echo "Created ~/workspace"
else
    echo "~/workspace already exists"
fi

echo "[1/4] Installing LLM CLI and extensions..."
run_task "installer/install_llm_cli.sh"

echo "[2/4] Initializing Bitwarden security..."
run_task "installer/initialize_security.sh"

echo "[3/4] Setting up workspace..."
run_task "settings/set_workspace.sh"

echo "[4/4] Setting up aliases and profile..."
run_task "settings/set_aliases.sh"

echo "[5/5] Registering MCP servers..."
run_task "settings/set_mcp_servers.sh"

echo "--- Setup Complete! ---"
echo "Please run 'source ~/.bash_profile' to apply changes."
