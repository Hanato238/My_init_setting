# apt packages required to run Orca as a headless server.
# Tailscale is installed separately via its own official install script
# (see install.sh), not through this list.
REMOTE_DEV_APT_PACKAGES=(
    curl
    libfuse2
    xvfb
)
