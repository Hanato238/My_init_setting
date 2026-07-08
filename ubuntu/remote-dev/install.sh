#!/bin/bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script with sudo. Run as your regular user:" >&2
    echo "  bash ./remote-dev/install.sh" >&2
    exit 1
fi

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

echo ""
echo "=== Remote dev setup finished ==="
echo ""
echo "Next steps (manual — require interactive auth / external console access):"
echo "  1. GCP-side (once, before or via VM recreation): enable 'IP forwarding'"
echo "     on the instance. This can only be set at instance creation time."
echo "  2. Authenticate Tailscale on this VM:"
echo "       sudo tailscale up --ssh --advertise-exit-node"
echo "     Then approve this VM as an exit node in the Tailscale admin console"
echo "     (only advertise/approve it if you actually want it as an exit node)."
echo "  3. Start the Orca server:"
echo "       sudo systemctl enable --now orca-serve.service"
echo "       sudo journalctl -u orca-serve -f   # find the pairing URL here"
echo "  4. Pair an external Orca client (desktop/mobile) using that pairing URL."
