# apt packages for the devbox image (see ../Dockerfile). google-chrome-stable
# comes from Google's own apt repo (added in the Dockerfile right before this
# list is installed), not Ubuntu's archive. fonts-liberation is listed
# explicitly because the Dockerfile uses --no-install-recommends, which would
# otherwise skip it and leave Chrome's font rendering broken.
DEVBOX_APT_PACKAGES=(
    curl
    git
    vim
    tmux
    build-essential
    ca-certificates
    gnupg
    python3
    python3-pip
    sudo
    # Browser for future nlm-login/gws-login OAuth flows via WSLg passthrough
    # (see ../setup.sh's GUI_DOCKER_ARGS and ../README.md).
    google-chrome-stable
    fonts-liberation
)
