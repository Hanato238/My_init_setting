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

case "$CATEGORY" in
    apps|update)
        run_if_exists "$SCRIPT_DIR/install_apps.sh"
        ;;
    mcp)
        run_if_exists "$SCRIPT_DIR/set_mcp_servers.sh"
        ;;
    aliases)
        run_if_exists "$SCRIPT_DIR/set_aliases.sh"
        ;;
    workspace)
        run_if_exists "$SCRIPT_DIR/set_workspace.sh"
        ;;
    mount-workspace)
        # Takes an extra arg (the Windows workspace dir's WSL path, e.g.
        # /mnt/c/Users/<user>/workspace) - not handled by run_if_exists,
        # which doesn't forward args. Normally invoked from
        # windows/settings/Set-WslWorkspaceMount.ps1; see mount_workspace.sh
        # for standalone usage.
        if [[ -f "$SCRIPT_DIR/mount_workspace.sh" ]]; then
            echo ""
            echo "=== Running: mount_workspace.sh ==="
            bash "$SCRIPT_DIR/mount_workspace.sh" "${2:-}"
        else
            echo "Warning: not found, skipping: $SCRIPT_DIR/mount_workspace.sh" >&2
        fi
        ;;
    security)
        run_if_exists "$SCRIPT_DIR/initialize_security.sh"
        ;;
    all)
        run_if_exists "$SCRIPT_DIR/install_apps.sh"
        run_if_exists "$SCRIPT_DIR/initialize_security.sh"
        run_if_exists "$SCRIPT_DIR/set_aliases.sh"
        run_if_exists "$SCRIPT_DIR/set_mcp_servers.sh"
        run_if_exists "$SCRIPT_DIR/set_workspace.sh"
        ;;
    *)
        echo "Unknown category: $CATEGORY" >&2
        echo "Usage: $0 [apps|update|mcp|aliases|workspace|mount-workspace|security|all]" >&2
        exit 1
        ;;
esac
