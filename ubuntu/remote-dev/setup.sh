#!/bin/bash
set -e

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

echo ""
echo "=== Remote dev setup finished ==="
echo ""
echo "Tailscale: $(tailscale ip -4 2>/dev/null || echo 'not authenticated yet')"
echo "orca-serve.service: $(systemctl is-active orca-serve.service 2>/dev/null || true)"
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
