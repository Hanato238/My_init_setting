# apt packages for the remote-agy environment (Tailscale/browser SSH access +
# GNOME desktop + Antigravity dev tooling). No RDP/VNC server is installed -
# GNOME is a local package only, reached (if at all) via the SSH session
# itself, not as a remote GUI. Tools that aren't plain apt packages
# (Tailscale, Node.js, uv, Antigravity CLI, notebooklm-mcp-cli, gws, gcloud
# CLI) are installed separately via their own official install
# scripts/package managers (or, for gcloud CLI, its own apt repo) in
# setup.sh, not through this list.
REMOTE_AGY_APT_PACKAGES=(
    curl
    wget
    git
    vim
    python3
    python3-pip
    # SSH access from the client PC (over the tailnet, or a browser-based SSH
    # console - see setup.sh)
    openssh-server
    # Used by the enable-tailnet-port/get-tailnet-ports login aliases (see
    # setup.sh) to scope inbound ports to the tailnet CIDR only.
    ufw
    # Full GNOME desktop meta-package, requested as a local package (no
    # RDP/VNC server is set up to reach it remotely).
    gnome
)
