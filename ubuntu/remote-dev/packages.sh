# apt packages for the remote-dev environment (Orca headless server + general
# dev tooling). Tools that aren't plain apt packages (Docker, GitHub CLI,
# Node.js, Claude Code, etc.) are installed separately via their own official
# install scripts in setup.sh, not through this list.
REMOTE_DEV_APT_PACKAGES=(
    curl
    libfuse2
    xvfb
    # GTK/Electron runtime deps required by the Orca AppImage (orca-ide) - without
    # these it fails at startup with "error while loading shared libraries:
    # libatk-1.0.so.0: cannot open shared object file" (exit code 127).
    libatk1.0-0
    libatk-bridge2.0-0
    libgtk-3-0
    libgbm1
    libasound2
    libnss3
    libxss1
    libxtst6
    # General dev tooling
    git
    vim
    python3
    python3-pip
    # Used by the enable-tailnet-port/get-tailnet-ports login aliases (see
    # setup.sh) to scope inbound ports to the tailnet CIDR only.
    ufw
)
