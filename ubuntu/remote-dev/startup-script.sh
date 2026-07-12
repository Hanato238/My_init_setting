#!/bin/bash
# GCE startup-script: bootstraps this VM unattended by cloning My_init_setting and
# running ubuntu/remote-dev/setup.sh (Tailscale + Orca headless server).
#
# Installed automatically by Create-Vm.ps1 via `--metadata-from-file startup-script=`.
# GCE runs this as root on every boot; it is safe to re-run (setup.sh is idempotent).
#
# Non-interactive Tailscale auth is enabled by setting the "tailscale-authkey"
# instance metadata attribute (see Create-Vm.ps1 -TailscaleAuthKey); without it,
# Tailscale auth is left as a manual step (see setup.sh's own output, viewable via
# `sudo journalctl -u google-startup-scripts -f`).
set -e

REPO_DIR="/opt/My_init_setting"
REPO_URL="https://github.com/Hanato238/My_init_setting.git"

if ! command -v git &>/dev/null; then
    apt-get update
    apt-get install -y git
fi

if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" pull --ff-only
else
    git clone "$REPO_URL" "$REPO_DIR"
fi

TAILSCALE_AUTHKEY="$(curl -sf -H 'Metadata-Flavor: Google' \
    'http://metadata.google.internal/computeMetadata/v1/instance/attributes/tailscale-authkey' \
    2>/dev/null || true)"
export TAILSCALE_AUTHKEY

bash "$REPO_DIR/ubuntu/remote-dev/setup.sh"
