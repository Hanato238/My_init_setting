#!/bin/bash
# aptをupgrade update
sudo apt-get -y update
sudo apt-get -y upgrade

# chrome remote desktopをインストールする
wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
sudo dpkg -i chrome-remote-desktop_current_amd64.deb
sudo apt intall --assume0yes --fix-broken
rm chrome-remote-desktop_current_amd64.deb

# google chromeをインストールする
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo apt-get install -f
rm google-chrome-stable_current_amd64.deb

# VScodeをインストールする
sudo snap install -y --classic code

# gitをインストールする
sudo apt-get install -y git

# expressVPNをインストールする
sudo apt-get install -y expressvpn

# curlをインストールする
sudo apt-get install -y curl

# vimをインストールする
sudo apt-get install -y vim

sudo apt autoremove -y
sudo reboot