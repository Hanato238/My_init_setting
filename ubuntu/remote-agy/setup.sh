#!/bin/bash
set -e

# GCE startup-scripts run as root without $HOME set, which trips up some
# third-party installers (e.g. the uv/Antigravity installers below) that
# assume it's always set.
export HOME="${HOME:-/root}"

# Safe to run as root (e.g. from a GCE startup-script, which always runs as root)
# or as a regular sudo-capable user - every step below goes through sudo, which
# is a no-op passthrough when already root. Also safe to re-run (every step below
# checks whether its target already exists before acting).
#
# Scope of this VM: reachable only via SSH from the client PC (Tailscale SSH,
# or a browser-based SSH console such as the Tailscale admin console or GCP's
# browser SSH), with Antigravity CLI / uv / notebooklm-mcp-cli / gws / gcloud
# CLI installed for agentic dev work. No GUI/desktop environment is
# installed. Also advertised as a Tailscale exit node (like
# remote-dev/life-os) - still requires approval in the Tailscale admin
# console either way.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./packages.sh
source "$SCRIPT_DIR/packages.sh"

echo "=== remote-agy VM setup (SSH + Antigravity dev tools) ==="

# GCE startup-scripts can run before the VM's network/DNS is fully settled, which
# makes the curl-based installers below (Tailscale, Antigravity CLI, uv, Node.js,
# gws) fail intermittently on first boot. Retry each one a few times with a short
# backoff instead of giving up (or, worse, letting `set -e` abort the rest of
# this idempotent script) on a single transient failure.
retry() {
    local attempts="$1" delay="$2"
    shift 2
    local n=1
    until "$@"; do
        if (( n >= attempts )); then
            return 1
        fi
        echo "  (attempt $n/$attempts failed, retrying in ${delay}s...)" >&2
        sleep "$delay"
        n=$((n + 1))
    done
}

if ! command -v systemctl &>/dev/null; then
    echo "Error: systemd is required for this setup (tailscaled/ssh service management)." >&2
    exit 1
fi

# --- apt prerequisites ---
sudo apt-get update
sudo apt-get install -y "${REMOTE_AGY_APT_PACKAGES[@]}"

# --- OpenSSH server ---
if systemctl is-active --quiet ssh; then
    echo "OK: sshd is already running"
else
    sudo systemctl enable --now ssh
fi

# --- Tailscale ---
# Installation failure here used to abort the whole script (bare statement
# under `set -e`), silently skipping every step below it - including the
# Antigravity CLI / uv / Node.js / gws installs much further down. Retry first
# (the common cause is a transient network/DNS hiccup right after boot); if it
# still fails, warn and continue instead of taking down the rest of setup.sh.
if command -v tailscale &>/dev/null; then
    echo "OK: tailscale is already installed ($(tailscale version | head -n1))"
elif retry 5 10 bash -c 'curl -fsSL https://tailscale.com/install.sh | sh'; then
    echo "OK: tailscale installed."
else
    echo "WARNING: Tailscale installation failed after retries - skipping Tailscale setup for this run." >&2
    echo "         Re-run this script (or reboot the VM) once network access is confirmed." >&2
fi

if command -v tailscale &>/dev/null; then
    if systemctl is-active --quiet tailscaled; then
        echo "OK: tailscaled is running"
    else
        sudo systemctl enable --now tailscaled
    fi

    # Authenticate non-interactively if TAILSCALE_AUTHKEY is set (e.g. passed via the
    # "tailscale-authkey" GCE instance metadata attribute - see Create-Vm.ps1
    # -TailscaleAuthKey). Otherwise this is left as a manual step (device auth flow
    # needs a browser). --ssh enables Tailscale SSH, the intended access path from
    # the client PC. --advertise-exit-node makes this VM available as a tailnet
    # exit node (still requires approval in the Tailscale admin console either way).
    if tailscale ip -4 &>/dev/null; then
        echo "OK: tailscale is already authenticated ($(tailscale ip -4))"
    elif [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
        echo "Authenticating Tailscale with the supplied auth key..."
        if retry 5 10 sudo tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh --advertise-exit-node; then
            echo "OK: tailscale authenticated ($(tailscale ip -4))."
        else
            echo "WARNING: Tailscale auth failed after retries - run 'sudo tailscale up --ssh --advertise-exit-node' manually." >&2
        fi
    else
        echo "NOTE: TAILSCALE_AUTHKEY not set - Tailscale auth left for the manual step below."
    fi
else
    echo "NOTE: tailscale is not installed - skipping tailscaled/auth steps."
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
# `tailscale up --ssh` above, which arrives over tailscale0, not port 22).
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

# --- Workspace repos (optional) ---
# Set via the "workspace-repo-urls" GCE instance metadata attribute (see
# vm-config.json's workspaceRepoUrls / Create-Vm.ps1) as a space-separated
# list of repo URLs. Cloning happens lazily on each user's first interactive
# login (via /etc/profile.d), NOT here at boot time - on first boot the OS
# login user's home directory often doesn't exist yet (GCE creates it on
# first login, which races with this script), so a one-shot clone here can
# easily miss it. Login-time is the first point $HOME is guaranteed to exist
# for any given user.
if [ -n "${WORKSPACE_REPO_URLS:-}" ]; then
    if ! command -v git &>/dev/null; then
        sudo apt-get install -y git
    fi
    echo "--- Workspace repos ($WORKSPACE_REPO_URLS) ---"
    sudo mkdir -p /etc/remote-agy
    echo "$WORKSPACE_REPO_URLS" | sudo tee /etc/remote-agy/workspace-repo-urls > /dev/null

    PROFILE_D_SCRIPT="/etc/profile.d/99-remote-agy-workspace.sh"
    echo "Installing/updating login-time workspace clone script at $PROFILE_D_SCRIPT..."
    sudo tee "$PROFILE_D_SCRIPT" > /dev/null << 'EOF'
# Auto-clone the workspace repos configured via vm-config.json's
# workspaceRepoUrls (see ubuntu/remote-agy/setup.sh) into ~/workspace on first
# interactive login. Runs for every login shell but does nothing once a repo
# is already cloned.
_repo_urls_file="/etc/remote-agy/workspace-repo-urls"
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
ALIASES_SCRIPT="/etc/profile.d/90-remote-agy-aliases.sh"
echo "Installing/updating login-time aliases at $ALIASES_SCRIPT..."
sudo tee "$ALIASES_SCRIPT" > /dev/null << 'EOF'
# Convenience aliases for the remote-agy VM (see ubuntu/remote-agy/setup.sh).

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

# --- Optional dev tooling ---
# Everything below is "nice to have" on top of the core SSH/Tailscale
# setup above, so each block is written so a failure prints a WARNING and moves on
# instead of aborting the whole script via `set -e` (a command used as an
# if/elif condition is exempt from `set -e`, which is what makes this safe).

# uv (Python package/version manager) - installed straight to /usr/local/bin
# via UV_INSTALL_DIR so it's on PATH for every login user, not just root
# (whose $HOME the installer would otherwise default to).
if command -v uv &>/dev/null; then
    echo "OK: uv is already installed ($(uv --version))"
elif retry 5 10 bash -c 'curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh'; then
    echo "OK: uv installed to /usr/local/bin."
else
    echo "WARNING: uv installation failed after retries - skipping." >&2
fi

# Antigravity CLI (agy) - the official installer drops the binary under
# $HOME/.local/bin (=/root/.local/bin while this script runs as root at boot),
# so it's moved to /usr/local/bin afterwards to be reachable by every login user.
if command -v agy &>/dev/null; then
    echo "OK: Antigravity CLI (agy) is already installed"
elif retry 5 10 bash -c 'curl -fsSL https://antigravity.google/cli/install.sh | bash'; then
    if [ -x "$HOME/.local/bin/agy" ]; then
        sudo mv "$HOME/.local/bin/agy" /usr/local/bin/agy
    fi
    echo "OK: Antigravity CLI installed."
else
    echo "WARNING: Antigravity CLI installation failed after retries - skipping." >&2
fi

# notebooklm-mcp-cli (uv tool) - UV_TOOL_DIR/UV_TOOL_BIN_DIR redirect the
# install to a shared location instead of root's home, same reasoning as uv above.
if command -v notebooklm-mcp-cli &>/dev/null; then
    echo "OK: notebooklm-mcp-cli is already installed"
elif command -v uv &>/dev/null && sudo env UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin uv tool install notebooklm-mcp-cli; then
    echo "OK: notebooklm-mcp-cli installed."
else
    echo "WARNING: notebooklm-mcp-cli installation failed - skipping." >&2
fi

# Node.js (required for the npm-based gws install below)
if command -v node &>/dev/null; then
    echo "OK: node is already installed ($(node --version))"
elif retry 5 10 bash -c 'curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs'; then
    echo "OK: Node.js installed ($(node --version))"
else
    echo "WARNING: Node.js installation failed after retries - skipping." >&2
fi

# gws (npm package @googleworkspace/cli). Requires GLIBC_2.39 (see
# vm-config.json's imageFamily - Ubuntu 24.04 ships glibc 2.39, 22.04 only 2.35).
if command -v gws &>/dev/null; then
    echo "OK: gws is already installed"
elif command -v npm &>/dev/null && retry 5 10 sudo npm install -g @googleworkspace/cli; then
    echo "OK: gws (@googleworkspace/cli) installed."
else
    echo "WARNING: gws (@googleworkspace/cli) installation failed after retries - skipping." >&2
fi

# gcloud CLI (Google Cloud SDK) - added via Google's official apt repo rather
# than a curl-pipe-bash installer, so it keeps updating via normal apt upgrade
# afterwards. --yes on gpg --dearmor keeps the key-import step idempotent
# across retries (it otherwise refuses to overwrite an existing key file
# non-interactively). Wrapped in `set -e` so any failed step inside the
# subshell fails the whole attempt and triggers a retry, same as the other
# curl-based installers above.
if command -v gcloud &>/dev/null; then
    echo "OK: gcloud CLI is already installed ($(gcloud --version | head -n1))"
elif retry 5 10 bash -c '
    set -e
    sudo apt-get install -y apt-transport-https ca-certificates gnupg
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y google-cloud-cli
'; then
    echo "OK: gcloud CLI installed ($(gcloud --version | head -n1))."
else
    echo "WARNING: gcloud CLI installation failed after retries - skipping." >&2
fi

echo ""
echo "=== remote-agy setup finished ==="
echo ""
if command -v tailscale &>/dev/null; then
    echo "Tailscale: $(tailscale ip -4 2>/dev/null || echo 'installed, not authenticated yet')"
else
    echo "Tailscale: not installed (installation failed after retries - see WARNING above; re-run this script)"
fi
echo "sshd: $(systemctl is-active ssh 2>/dev/null || true)"
echo "ufw: $(sudo ufw status 2>/dev/null | head -n1 || echo 'not installed')"
if [ -n "${WORKSPACE_REPO_URLS:-}" ]; then
    echo "Workspace repos cloned per SSH user on their first login:"
    for _repo_url in $WORKSPACE_REPO_URLS; do
        echo "  ~/workspace/$(basename "$_repo_url" .git)"
    done
    unset _repo_url
fi
echo ""
echo "Remaining manual steps:"
if ! command -v tailscale &>/dev/null; then
    echo "  - Tailscale itself failed to install (see WARNING above) - re-run:"
    echo "      sudo bash /opt/My_init_setting/ubuntu/remote-agy/setup.sh"
elif ! tailscale ip -4 &>/dev/null; then
    echo "  - Authenticate Tailscale on this VM (no TAILSCALE_AUTHKEY was supplied):"
    echo "      sudo tailscale up --ssh --advertise-exit-node"
fi
echo "  - If you want to use this VM as a Tailscale exit node, approve it in the"
echo "    Tailscale admin console (advertisement alone isn't enough)."
echo ""
echo "Login shells get ts-ip / ts-status aliases, plus"
echo "enable-tailnet-port <port> [tcp|udp] / get-tailnet-ports (ufw rules scoped"
echo "to the tailnet CIDR, auto-detected from this VM's Tailscale IP) - open a"
echo "new shell (or 'source /etc/profile.d/90-remote-agy-aliases.sh') to pick"
echo "them up."
