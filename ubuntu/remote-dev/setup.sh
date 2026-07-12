#!/bin/bash
set -e

# GCE startup-scripts run as root without $HOME set, which trips up some
# third-party installers (e.g. the Antigravity CLI installer below) that
# assume it's always set.
export HOME="${HOME:-/root}"

# Safe to run as root (e.g. from a GCE startup-script, which always runs as root)
# or as a regular sudo-capable user - every step below goes through sudo, which
# is a no-op passthrough when already root. Also safe to re-run (every step below
# checks whether its target already exists before acting).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./packages.sh
source "$SCRIPT_DIR/packages.sh"

echo "=== Remote dev environment setup (Tailscale + Orca headless server) ==="

if ! command -v systemctl &>/dev/null; then
    echo "Error: systemd is required for this setup (Tailscale + Orca service management)." >&2
    exit 1
fi

# --- apt prerequisites (for the Orca AppImage) ---
sudo apt-get update
sudo apt-get install -y "${REMOTE_DEV_APT_PACKAGES[@]}"

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
# needs a browser).
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

# --- Workspace repo (optional) ---
# Set via the "workspace-repo-url" GCE instance metadata attribute (see
# vm-config.json's workspaceRepoUrl / Create-Vm.ps1). Cloning happens lazily
# on each user's first interactive login (via /etc/profile.d), NOT here at
# boot time - on first boot the OS login user's home directory often doesn't
# exist yet (GCE creates it on first `gcloud compute ssh`, which races with
# this script), so a one-shot clone here can easily miss it. Login-time is
# the first point $HOME is guaranteed to exist for any given user.
if [ -n "${WORKSPACE_REPO_URL:-}" ]; then
    if ! command -v git &>/dev/null; then
        sudo apt-get install -y git
    fi
    echo "--- Workspace repo ($WORKSPACE_REPO_URL) ---"
    sudo mkdir -p /etc/remote-dev
    echo "$WORKSPACE_REPO_URL" | sudo tee /etc/remote-dev/workspace-repo-url > /dev/null

    PROFILE_D_SCRIPT="/etc/profile.d/99-remote-dev-workspace.sh"
    echo "Installing/updating login-time workspace clone script at $PROFILE_D_SCRIPT..."
    sudo tee "$PROFILE_D_SCRIPT" > /dev/null << 'EOF'
# Auto-clone the workspace repo configured via vm-config.json's
# workspaceRepoUrl (see ubuntu/remote-dev/setup.sh) into ~/workspace on first
# interactive login. Runs for every login shell but does nothing once the
# repo is already cloned. Service accounts (e.g. "orca", shell=/usr/sbin/nologin)
# never get an interactive login shell, so this never runs for them.
_repo_url_file="/etc/remote-dev/workspace-repo-url"
if [ -r "$_repo_url_file" ] && [ -n "$HOME" ] && command -v git >/dev/null 2>&1; then
    _repo_url="$(cat "$_repo_url_file")"
    _repo_name="$(basename "$_repo_url" .git)"
    _dest="$HOME/workspace/$_repo_name"
    if [ -n "$_repo_url" ] && [ ! -d "$_dest/.git" ]; then
        mkdir -p "$HOME/workspace"
        git clone "$_repo_url" "$_dest"
    fi
fi
unset _repo_url_file _repo_url _repo_name _dest
EOF
else
    echo "NOTE: workspace-repo-url not set - skipping workspace auto-clone setup."
fi

# --- Orca headless server (AppImage) ---
ORCA_DIR="/opt/orca"
ORCA_BIN="$ORCA_DIR/orca-linux.AppImage"
if [ -x "$ORCA_BIN" ]; then
    echo "OK: Orca is already installed at $ORCA_BIN"
else
    echo "Installing Orca (headless AppImage)..."
    sudo mkdir -p "$ORCA_DIR"
    sudo curl -L https://github.com/stablyai/orca/releases/latest/download/orca-linux.AppImage \
        -o "$ORCA_BIN"
    sudo chmod +x "$ORCA_BIN"
fi

# --- Orca CLI (same AppImage - links it onto PATH as `orca`) ---
# `orca serve` runs the headless server (see the systemd service below); the same
# binary also exposes CLI subcommands (`orca worktree create`, `orca snapshot`,
# `orca click`, `orca fill`, ...) for scripting against a running/paired server.
ORCA_CLI_LINK="/usr/local/bin/orca"
if [ -L "$ORCA_CLI_LINK" ] && [ "$(readlink -f "$ORCA_CLI_LINK")" = "$(readlink -f "$ORCA_BIN")" ]; then
    echo "OK: orca CLI already linked at $ORCA_CLI_LINK"
else
    echo "Linking orca CLI to $ORCA_CLI_LINK..."
    sudo ln -sf "$ORCA_BIN" "$ORCA_CLI_LINK"
fi

# Dedicated non-root user to run the orca-serve service
if ! id -u orca &>/dev/null; then
    sudo useradd --system --create-home --shell /usr/sbin/nologin orca
fi
sudo chown -R orca:orca "$ORCA_DIR"

# systemd service (waits for a Tailscale IP so it survives reboots before auth
# has run, and always pairs on the current Tailscale address)
SERVICE_FILE="/etc/systemd/system/orca-serve.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo "Creating orca-serve.service..."
    sudo tee "$SERVICE_FILE" > /dev/null << 'EOF'
[Unit]
Description=Orca runtime server
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=simple
User=orca
Environment=LIBGL_ALWAYS_SOFTWARE=1
ExecStartPre=/bin/sh -c 'until tailscale ip -4 >/dev/null 2>&1; do sleep 1; done'
ExecStart=/bin/sh -c '/opt/orca/orca-linux.AppImage serve --port 6768 --pairing-address "$(tailscale ip -4)"'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
else
    echo "OK: $SERVICE_FILE already exists — leaving as-is."
fi

# Start it now - ExecStartPre in the unit above waits for a Tailscale IP, so this
# is safe to enable even before Tailscale has authenticated (e.g. no
# TAILSCALE_AUTHKEY was supplied): the service just sits in "activating" until
# Tailscale comes up, then starts itself.
sudo systemctl enable --now orca-serve.service

# --- Optional dev tooling ---
# Everything below is "nice to have" on top of the core Tailscale + Orca setup
# above, so each block is written so a failure prints a WARNING and moves on
# instead of aborting the whole script via `set -e` (a command used as an
# if/elif condition is exempt from `set -e`, which is what makes this safe).
if command -v node &>/dev/null; then
    echo "OK: node is already installed ($(node --version))"
elif curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs; then
    echo "OK: Node.js installed ($(node --version))"
else
    echo "WARNING: Node.js installation failed - skipping (not required for Tailscale/Orca)." >&2
fi

if command -v docker &>/dev/null; then
    echo "OK: docker is already installed ($(docker --version))"
elif curl -fsSL https://get.docker.com | sudo sh; then
    echo "OK: Docker installed."
else
    echo "WARNING: Docker installation failed - skipping (not required for Tailscale/Orca)." >&2
fi

if command -v gh &>/dev/null; then
    echo "OK: gh is already installed ($(gh --version | head -n1))"
elif sudo mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt-get update \
    && sudo apt-get install -y gh; then
    echo "OK: GitHub CLI installed."
else
    echo "WARNING: GitHub CLI installation failed - skipping (not required for Tailscale/Orca)." >&2
fi

if command -v claude &>/dev/null; then
    echo "OK: claude-code is already installed ($(claude --version 2>/dev/null || echo installed))"
elif sudo npm install -g @anthropic-ai/claude-code; then
    echo "OK: Claude Code CLI installed."
else
    echo "WARNING: Claude Code CLI installation failed - skipping." >&2
fi

if npm list -g @anthropic-ai/claude-agent-sdk &>/dev/null; then
    echo "OK: @anthropic-ai/claude-agent-sdk already installed"
elif sudo npm install -g @anthropic-ai/claude-agent-sdk; then
    echo "OK: Claude Agent SDK (npm) installed."
else
    echo "WARNING: Claude Agent SDK (npm) installation failed - skipping." >&2
fi

if python3 -m pip show claude-agent-sdk &>/dev/null; then
    echo "OK: claude-agent-sdk (pip) already installed"
elif sudo python3 -m pip install claude-agent-sdk; then
    echo "OK: Claude Agent SDK (pip) installed."
else
    echo "WARNING: Claude Agent SDK (pip) installation failed - skipping." >&2
fi

# LINE LIFF SDK: normally a per-project npm dependency rather than something
# installed system-wide, but requested as a global install for this VM.
if npm list -g @line/liff &>/dev/null; then
    echo "OK: @line/liff already installed"
elif sudo npm install -g @line/liff; then
    echo "OK: LINE LIFF SDK installed."
else
    echo "WARNING: LINE LIFF SDK installation failed - skipping." >&2
fi

if command -v agy &>/dev/null; then
    echo "OK: Antigravity CLI (agy) is already installed"
elif curl -fsSL https://antigravity.google/cli/install.sh | bash; then
    echo "OK: Antigravity CLI installed."
else
    echo "WARNING: Antigravity CLI installation failed - skipping." >&2
fi

echo ""
echo "=== Remote dev setup finished ==="
echo ""
echo "Tailscale: $(tailscale ip -4 2>/dev/null || echo 'not authenticated yet')"
echo "orca-serve.service: $(systemctl is-active orca-serve.service 2>/dev/null || true)"
if [ -n "${WORKSPACE_REPO_URL:-}" ]; then
    echo "Workspace: ~/workspace/$(basename "$WORKSPACE_REPO_URL" .git) (cloned on each user's first login)"
fi
echo ""
echo "Remaining manual steps:"
if ! tailscale ip -4 &>/dev/null; then
    echo "  - Authenticate Tailscale on this VM (no TAILSCALE_AUTHKEY was supplied):"
    echo "      sudo tailscale up --ssh --advertise-exit-node"
fi
echo "  - If this VM should be a Tailscale exit node, approve it in the Tailscale"
echo "    admin console (only advertise/approve it if you actually want one)."
echo "  - Pair an external Orca client (desktop/mobile) using the pairing URL:"
echo "      sudo journalctl -u orca-serve -f"
echo ""
echo "The 'orca' CLI command is on PATH (symlinked to the AppImage) - use it for"
echo "scripting, e.g. 'orca worktree create', once a server is paired."
