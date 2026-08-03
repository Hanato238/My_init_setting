#!/data/data/com.termux/files/usr/bin/bash
# install_proot_ubuntu.sh - Install proot-distro and bootstrap an Ubuntu rootfs.
# Termux host only. Antigravity CLI needs a glibc userland, which proot-distro's
# Ubuntu provides (Termux itself uses Android's Bionic libc).
set -e

echo "--- Installing proot-distro ---"
pkg update -y
pkg install -y proot-distro

INSTALLED_DIR="${PREFIX:-/data/data/com.termux/files/usr}/var/lib/proot-distro/installed-rootfs/ubuntu"

if [ -d "$INSTALLED_DIR" ]; then
    echo "Ubuntu rootfs already installed."
else
    echo "--- Installing Ubuntu rootfs (this may take a while) ---"
    proot-distro install ubuntu
fi

echo "proot-distro Ubuntu setup complete."
