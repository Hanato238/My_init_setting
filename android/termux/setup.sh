#!/data/data/com.termux/files/usr/bin/bash
# setup.sh - Main setup entry point for Termux
set -e

BASE_URL="https://raw.githubusercontent.com/hanato238/My_init_setting/main/android/termux"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Function to run scripts locally if available, otherwise download
run_task() {
    local script_rel_path="$1"
    local script_url="$BASE_URL/$script_rel_path"
    local local_script="$SCRIPT_DIR/$script_rel_path"

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

# Antigravity CLI does not work on Termux itself (Android's Bionic libc), so on
# a Termux host we only bootstrap proot-distro + Ubuntu here, then hand off:
# the rest of this script must be run again from inside that Ubuntu shell.
# Note: `command -v pkg` alone is not enough to detect the host, because
# `proot-distro login` inherits Termux's PATH into the Ubuntu guest, making
# `pkg` still resolve there. /etc/os-release only exists inside a real distro
# (Ubuntu/Debian), never on bare Termux/Android, so check that first.
if [ ! -f /etc/os-release ] && command -v pkg &>/dev/null; then
    echo "--- Termux host detected: bootstrapping proot-distro Ubuntu ---"
    run_task "installer/install_proot_ubuntu.sh"
    echo ""
    echo "--- proot-distro Ubuntu is ready ---"
    echo "Log into Ubuntu and re-run this script from there:"
    echo ""
    echo "  proot-distro login ubuntu --bind \"\$HOME\":\"\$HOME\" -- env HOME=\"\$HOME\" bash"
    echo "  cd '$SCRIPT_DIR'"
    echo "  bash setup.sh"
    echo ""
    exit 0
fi

echo "--- Starting Environment Setup (Ubuntu / proot-distro) ---"

if [ ! -d "$HOME/workspace" ]; then
    mkdir -p "$HOME/workspace"
    echo "Created ~/workspace"
else
    echo "~/workspace already exists"
fi

echo "[1/5] Installing Antigravity CLI..."
run_task "installer/install_llm_cli.sh"

echo "[2/5] Initializing Bitwarden security..."
run_task "installer/initialize_security.sh"

echo "[3/5] Setting up workspace..."
run_task "settings/set_workspace.sh"

echo "[4/5] Setting up aliases and profile..."
run_task "settings/set_aliases.sh"

echo "[5/5] Registering MCP servers..."
run_task "settings/set_mcp_servers.sh"

echo "--- Setup Complete! ---"
echo "Please run 'source ~/.bash_profile' to apply changes."
