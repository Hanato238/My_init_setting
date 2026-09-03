#!/bin/bash
set -e

# GCE startup-scripts run as root without $HOME set, which trips up some
# tools that assume it's always set.
export HOME="${HOME:-/root}"

# Safe to run as root (e.g. from a GCE startup-script, which always runs as root)
# or as a regular sudo-capable user - every step below goes through sudo, which
# is a no-op passthrough when already root. Also safe to re-run (every step below
# checks whether its target already exists before acting).
#
# Scope of this VM: hold a git clone of the target repo, reachable only via
# Tailscale SSH, and act as a Tailscale exit node. There is no long-running
# service, no Docker, and no automated push credentials (see README.md) - a
# human logs in over Tailscale SSH, edits/commits, and pushes manually.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./packages.sh
source "$SCRIPT_DIR/packages.sh"

echo "=== life-os VM setup (Tailscale SSH + exit node + repo clone) ==="

if ! command -v systemctl &>/dev/null; then
    echo "Error: systemd is required for this setup (tailscaled service management)." >&2
    exit 1
fi

# --- apt prerequisites ---
sudo apt-get update
sudo apt-get install -y "${LIFE_OS_APT_PACKAGES[@]}"

# --- Tailscale ---
if command -v tailscale &>/dev/null; then
    echo "OK: tailscale is already installed ($(tailscale version | head -n1))"
else
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

if systemctl is-active --quiet tailscaled; then
    echo "OK: tailscaled is running"
else
    sudo systemctl enable --now tailscaled
fi

# Authenticate non-interactively if TAILSCALE_AUTHKEY is set (e.g. passed via the
# "tailscale-authkey" GCE instance metadata attribute - see Create-Vm.ps1
# -TailscaleAuthKey). Otherwise this is left as a manual step (device auth flow
# needs a browser). --ssh enables Tailscale SSH (the only intended access path
# for this VM) and --advertise-exit-node is always requested, since this VM's
# purpose includes acting as a tailnet exit node (still requires approval in
# the Tailscale admin console either way - see README.md).
if tailscale ip -4 &>/dev/null; then
    echo "OK: tailscale is already authenticated ($(tailscale ip -4))"
elif [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
    echo "Authenticating Tailscale with the supplied auth key..."
    sudo tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --advertise-exit-node
else
    echo "NOTE: TAILSCALE_AUTHKEY not set - Tailscale auth left for the manual step below."
fi

# Enable IP forwarding (required to advertise this VM as an exit node)
SYSCTL_CONF="/etc/sysctl.d/99-tailscale.conf"
if [ ! -f "$SYSCTL_CONF" ]; then
    echo "Enabling IP forwarding for exit node support..."
    printf 'net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1\n' | sudo tee "$SYSCTL_CONF" > /dev/null
    sudo sysctl -p "$SYSCTL_CONF" > /dev/null
else
    echo "OK: IP forwarding already configured ($SYSCTL_CONF)"
fi

# --- Host firewall (ufw) ---
# Default-deny inbound, but only after the rules below are in place so this
# never locks out the connection that's running this script: port 22/tcp
# (GCE OS Login / initial provisioning access, which happens over eth0, not
# Tailscale) and the whole tailscale0 interface (Tailscale already
# authenticates/encrypts that traffic - this also covers Tailscale SSH from
# `tailscale up --ssh` above, the only intended access path for this VM).
# Once this is active, individual extra tailnet-only ports are opened on
# demand via the enable-tailnet-port login alias below instead of being added
# here.
if command -v ufw &>/dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        echo "OK: ufw is already active"
    else
        echo "Enabling ufw (allowing SSH + tailscale0 first so this doesn't lock out access)..."
        sudo ufw allow 22/tcp comment 'ssh (host access)'
        sudo ufw allow in on tailscale0 comment 'tailscale (trusted)'
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw --force enable
    fi
else
    echo "NOTE: ufw not installed - skipping firewall enablement."
fi

# --- Workspace repo (optional) ---
# Set via the "workspace-repo-urls" GCE instance metadata attribute (see
# vm-config.json's workspaceRepoUrls / Create-Vm.ps1) as a space-separated
# list of repo URLs. Cloning happens lazily on each user's first interactive
# login (via /etc/profile.d), NOT here at boot time - on first boot the OS
# login user's home directory often doesn't exist yet (GCE creates it on
# first `gcloud compute ssh`/Tailscale SSH login, which races with this
# script), so a one-shot clone here can easily miss it. Login-time is the
# first point $HOME is guaranteed to exist for any given user.
#
# Push authentication is intentionally left manual (see README.md): after
# logging in, run `gh auth login` or install an SSH deploy key yourself. That
# setup persists on the boot disk across reconnects/reboots - it's only lost
# if the VM is deleted and recreated (`Create-Vm.ps1 -Recreate`). If the
# cloned repo is private, the same manual auth is also needed before the
# initial clone below will succeed (this script assumes a public repo URL).
if [ -n "${WORKSPACE_REPO_URLS:-}" ]; then
    if ! command -v git &>/dev/null; then
        sudo apt-get install -y git
    fi
    echo "--- Workspace repo(s): $WORKSPACE_REPO_URLS ---"
    sudo mkdir -p /etc/life-os
    echo "$WORKSPACE_REPO_URLS" | sudo tee /etc/life-os/workspace-repo-urls > /dev/null

    PROFILE_D_SCRIPT="/etc/profile.d/99-life-os-workspace.sh"
    echo "Installing/updating login-time workspace clone script at $PROFILE_D_SCRIPT..."
    sudo tee "$PROFILE_D_SCRIPT" > /dev/null << 'EOF'
# Auto-clone the workspace repo(s) configured via vm-config.json's
# workspaceRepoUrls (see ubuntu/life-os/setup.sh) into ~/workspace on first
# interactive login. Runs for every login shell but does nothing once a repo
# is already cloned.
_repo_urls_file="/etc/life-os/workspace-repo-urls"
if [ -r "$_repo_urls_file" ] && [ -n "$HOME" ] && command -v git >/dev/null 2>&1; then
    for _repo_url in $(cat "$_repo_urls_file"); do
        _repo_name="$(basename "$_repo_url" .git)"
        _dest="$HOME/workspace/$_repo_name"
        if [ ! -d "$_dest/.git" ]; then
            mkdir -p "$HOME/workspace"
            git clone "$_repo_url" "$_dest"
        fi
    done
fi
unset _repo_urls_file _repo_url _repo_name _dest
EOF
else
    echo "NOTE: workspace-repo-urls not set - skipping workspace auto-clone setup."
fi

# --- Convenience aliases (login-time) ---
ALIASES_SCRIPT="/etc/profile.d/90-life-os-aliases.sh"
echo "Installing/updating login-time aliases at $ALIASES_SCRIPT..."
sudo tee "$ALIASES_SCRIPT" > /dev/null << 'EOF'
# Convenience aliases for the life-os VM (see ubuntu/life-os/setup.sh).

alias ts-ip='tailscale ip -4'
alias ts-status='tailscale status'

# Ported from ubuntu/remote-dev/setup.sh. Uses ufw with a fixed comment tag so
# rules added here can be found again later; the tailnet CIDR is
# auto-detected from this machine's current Tailscale IP (Tailscale always
# assigns from the 100.64.0.0/10 CGNAT range) rather than hardcoded.
enable-tailnet-port() {
    local port="$1"
    local proto="${2:-tcp}"

    if [ -z "$port" ]; then
        echo "Usage: enable-tailnet-port <port> [tcp|udp]" >&2
        return 1
    fi
    if ! command -v ufw &>/dev/null; then
        echo "enable-tailnet-port: ufw not found (sudo apt-get install ufw)" >&2
        return 1
    fi

    local ts_ip
    ts_ip="$(tailscale ip -4 2>/dev/null)"
    if [ -z "$ts_ip" ]; then
        echo "enable-tailnet-port: could not get Tailscale IP - is tailscale running?" >&2
        return 1
    fi

    local o1 o2 masked tailnet_cidr
    o1="$(cut -d. -f1 <<< "$ts_ip")"
    o2="$(cut -d. -f2 <<< "$ts_ip")"
    masked=$(( o2 & 0xC0 ))
    tailnet_cidr="${o1}.${masked}.0.0/10"

    sudo ufw allow from "$tailnet_cidr" to any port "$port" proto "$proto" comment 'tailnet-only'
    echo "ufw rule added: $proto/$port allowed from $tailnet_cidr (detected via $ts_ip)"
}

get-tailnet-ports() {
    if ! command -v ufw &>/dev/null; then
        echo "get-tailnet-ports: ufw not found" >&2
        return 1
    fi
    sudo ufw status numbered | grep 'tailnet-only' || echo "No tailnet-only ufw rules found."
}
EOF

echo ""
echo "=== life-os setup finished ==="
echo ""
echo "Tailscale: $(tailscale ip -4 2>/dev/null || echo 'not authenticated yet')"
echo "ufw: $(sudo ufw status 2>/dev/null | head -n1 || echo 'not installed')"
if [ -n "${WORKSPACE_REPO_URLS:-}" ]; then
    echo "Workspace repo(s) cloned per SSH user on their first login:"
    for _repo_url in $WORKSPACE_REPO_URLS; do
        echo "  ~/workspace/$(basename "$_repo_url" .git)"
    done
    unset _repo_url
fi
echo ""
echo "Remaining manual steps:"
if ! tailscale ip -4 &>/dev/null; then
    echo "  - Authenticate Tailscale on this VM (no TAILSCALE_AUTHKEY was supplied):"
    echo "      sudo tailscale up --ssh --advertise-exit-node"
fi
echo "  - Approve this VM as an exit node in the Tailscale admin console."
echo "  - Set up git push credentials once, after logging in (gh auth login, or"
echo "    an SSH deploy key) - intentionally not automated. See README.md."
echo ""
echo "Login shells get ts-ip / ts-status aliases, plus enable-tailnet-port"
echo "<port> [tcp|udp] / get-tailnet-ports (ufw rules scoped to the tailnet"
echo "CIDR, auto-detected from this VM's Tailscale IP) - open a new shell (or"
echo "'source /etc/profile.d/90-life-os-aliases.sh') to pick them up."
