#!/bin/bash
set -e

# Desktop Environment
sudo apt-get update
sudo apt-get install -y lubuntu-desktop

# Google Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb || sudo apt-get install -f -y
rm google-chrome-stable_current_amd64.deb

# Chrome Remote Desktop
wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
sudo dpkg -i chrome-remote-desktop_current_amd64.deb || sudo apt-get install -f -y
rm chrome-remote-desktop_current_amd64.deb

# VSCode
sudo snap install --classic code

# Telegram & Zoom
sudo snap install telegram-desktop
wget https://zoom.us/client/latest/zoom_amd64.deb
sudo dpkg -i zoom_amd64.deb || sudo apt-get install -f -y
rm zoom_amd64.deb

# Bitwarden GUI
sudo snap install bitwarden

# TeamViewer
wget https://download.teamviewer.com/download/linux/teamviewer_amd64.deb
sudo dpkg -i teamviewer_amd64.deb || sudo apt-get install -f -y
rm teamviewer_amd64.deb

echo "GUI setup complete. Please reboot to start the desktop environment."
