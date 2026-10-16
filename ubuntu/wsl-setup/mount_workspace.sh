#!/bin/bash
set -e

# Bind-mounts a Windows-side directory (passed as $1, already converted to
# its WSL path form, e.g. /mnt/c/Users/<user>/workspace - see
# windows/settings/Set-WslWorkspaceMount.ps1, which does that conversion via
# `wsl wslpath` before calling this script) onto $HOME/workspace inside WSL.
# After this, the Windows-side workspace (windows/settings/Set-Workspace.ps1)
# and the WSL-side ~/workspace (normally set up independently by
# set_workspace.sh) are the exact same directory instead of two separate
# copies.
#
# Persisted via /etc/fstab (bind mount), so it survives `wsl --shutdown`/
# reboot, not just this shell session - same reasoning as the devbox
# persistence story in ubuntu/devbox/README.md: a live mount is just
# process/kernel state and doesn't survive a restart on its own, so it has to
# be re-declared somewhere WSL reads it from on every boot.
#
# Caveat: files under /mnt/c (DrvFs) don't have native Unix permissions or
# symlinks unless WSL's automount is given `options = "metadata"` in
# /etc/wsl.conf's [automount] section (a separate, broader change affecting
# all of /mnt/c - not done here). Without it, git repos living in the
# mounted workspace may show every file as the same permissions/executable
# bit and can't store symlinks. Fine for most editing workflows; worth
# knowing if git starts behaving oddly.
#
# Usage: mount_workspace.sh <windows-workspace-wsl-path>
# Normally invoked via `wsl-setup/setup.sh mount-workspace <path>` from
# Set-WslWorkspaceMount.ps1, but safe to run directly inside WSL too.

WIN_WORKSPACE="${1:?Usage: $0 <windows-workspace-wsl-path>}"
WORKSPACE="$HOME/workspace"
FSTAB="/etc/fstab"
WSL_CONF="/etc/wsl.conf"

if [ ! -d "$WIN_WORKSPACE" ]; then
    echo "Error: $WIN_WORKSPACE does not exist (create it on the Windows side first, e.g. windows/settings/Set-Workspace.ps1)." >&2
    exit 1
fi

mkdir -p "$WORKSPACE"

if mountpoint -q "$WORKSPACE"; then
    echo "OK: $WORKSPACE is already mounted."
else
    if [ -n "$(ls -A "$WORKSPACE" 2>/dev/null)" ]; then
        echo "WARNING: $WORKSPACE already has contents - they'll be hidden (not deleted)" >&2
        echo "         underneath the bind mount while it's active. Move anything you" >&2
        echo "         want to keep out of $WORKSPACE first if that matters." >&2
    fi
    echo "Bind-mounting $WIN_WORKSPACE onto $WORKSPACE..."
    sudo mount --bind "$WIN_WORKSPACE" "$WORKSPACE"
fi

# --- Persist across reboots via /etc/fstab ---
if grep -qF " $WORKSPACE " "$FSTAB" 2>/dev/null; then
    echo "OK: $FSTAB already has an entry for $WORKSPACE"
else
    echo "Adding fstab entry so this survives 'wsl --shutdown'/reboot..."
    echo "$WIN_WORKSPACE $WORKSPACE none bind 0 0" | sudo tee -a "$FSTAB" > /dev/null
fi

# --- Ensure WSL actually processes /etc/fstab on startup ---
# mountFsTab defaults to true, but set it explicitly in case it was ever
# disabled. Mirrors the [boot]/systemd=true sed pattern in install_apps.sh -
# only touches the [automount] section, leaves [boot] etc. alone.
if grep -q "^mountFsTab" "$WSL_CONF" 2>/dev/null; then
    echo "OK: $WSL_CONF already has an explicit mountFsTab setting"
elif grep -q "\[automount\]" "$WSL_CONF" 2>/dev/null; then
    sudo sed -i '/\[automount\]/a mountFsTab = true' "$WSL_CONF"
    echo "Added mountFsTab = true under the existing [automount] section in $WSL_CONF"
else
    printf '\n[automount]\nmountFsTab = true\n' | sudo tee -a "$WSL_CONF" > /dev/null
    echo "Added [automount] section to $WSL_CONF"
fi

echo ""
echo "Done: $WORKSPACE is bound to $WIN_WORKSPACE (effective immediately, and"
echo "persisted via $FSTAB for future WSL restarts)."
