# apt packages required to run Orca as a headless server.
# Tailscale is installed separately via its own official install script
# (see setup.sh), not through this list.
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
)
