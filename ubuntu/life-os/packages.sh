# apt packages for the life-os VM (Tailscale SSH access/exit node + a git
# clone to work in). Deliberately minimal - this VM's only job is to hold a
# clone of the target repo for manual SSH-driven edit/push; no Docker, no
# Orca, no language runtimes are installed here (see setup.sh's header comment).
LIFE_OS_APT_PACKAGES=(
    curl
    git
    vim
    # Used by the enable-tailnet-port/get-tailnet-ports login aliases (see
    # setup.sh) to scope inbound ports to the tailnet CIDR only.
    ufw
)
