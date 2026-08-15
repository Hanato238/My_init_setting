# apt packages for the remote-agy environment (Tailscale SSH access + an
# on-demand xrdp GUI, reached over the tailnet + Antigravity dev tooling).
# Tools that aren't plain apt packages (Tailscale, Node.js, uv, Antigravity
# CLI, notebooklm-mcp-cli, gws) are installed separately via their own
# official install scripts/package managers in setup.sh, not through this list.
REMOTE_AGY_APT_PACKAGES=(
    curl
    wget
    git
    vim
    python3
    python3-pip
    # SSH access from the client PC (over the tailnet - see setup.sh)
    openssh-server
    # Used by the enable-tailnet-port/get-tailnet-ports login aliases (see
    # setup.sh) to scope inbound ports to the tailnet CIDR only.
    ufw
    # Desktop environment for the xrdp session (see setup.sh's ~/.xsession
    # setup) + the RDP server itself. GNOME Flashback (not vanilla GNOME
    # Shell) - GNOME Shell/Mutter has known black-screen/session-crash issues
    # over xrdp's Xorg backend, while Flashback (classic GNOME 2-style
    # panel+metacity) is well-proven with xrdp.
    gnome-session-flashback
    dbus-x11
    x11-xserver-utils
    xrdp
)
