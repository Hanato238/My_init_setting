#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATEGORY="${1:-all}"

run_if_exists() {
    local path="$1"
    if [[ -f "$path" ]]; then
        echo ""
        echo "=== Running: $(basename "$path") ==="
        bash "$path"
    else
        echo "Warning: not found, skipping: $path" >&2
    fi
}

is_wsl() {
    grep -qiE "microsoft|WSL" /proc/version 2>/dev/null
}

case "$CATEGORY" in
    apps)
        run_if_exists "$SCRIPT_DIR/installer/install_apps.sh"
        ;;
    mcp)
        run_if_exists "$SCRIPT_DIR/settings/set_mcp_servers.sh"
        ;;
    aliases)
        run_if_exists "$SCRIPT_DIR/settings/set_aliases.sh"
        ;;
    workspace)
        run_if_exists "$SCRIPT_DIR/settings/set_workspace.sh"
        ;;
    security)
        run_if_exists "$SCRIPT_DIR/installer/initialize_security.sh"
        ;;
    gui)
        if is_wsl; then
            echo "Skipping gui: not supported on WSL." >&2
            exit 0
        fi
        run_if_exists "$SCRIPT_DIR/settings/set_gui.sh"
        ;;
    remote-dev)
        run_if_exists "$SCRIPT_DIR/installer/install_remote_dev.sh"
        ;;
    all)
        run_if_exists "$SCRIPT_DIR/installer/install_apps.sh"
        run_if_exists "$SCRIPT_DIR/installer/initialize_security.sh"
        run_if_exists "$SCRIPT_DIR/settings/set_aliases.sh"
        run_if_exists "$SCRIPT_DIR/settings/set_mcp_servers.sh"
        run_if_exists "$SCRIPT_DIR/settings/set_workspace.sh"
        if ! is_wsl; then
            run_if_exists "$SCRIPT_DIR/settings/set_gui.sh"
        fi
        ;;
    *)
        echo "Unknown category: $CATEGORY" >&2
        echo "Usage: $0 [apps|mcp|aliases|workspace|security|gui|remote-dev|all]" >&2
        exit 1
        ;;
esac
