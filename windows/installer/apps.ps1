Set-ExecutionPolicy Bypass -Scope Process -Force

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey is not installed. Please install Chocolatey first." -ForegroundColor Red
    return
}

# install Google Chrome
choco install googlechrome --ignore-checksums -y
# install Google Drive
choco install googledrvie --ignore-checksums -y
choco install google-drive-file-stream --ignore-checksums -y
# install Git
choco install git -y

# install python 3.9, 3.10, 3.11, 3.12, 3.13
choco install python39 python310 pytnon311 python312 python313 python314-y
# install vscode
choco install vscode -y
# install ubuntu 22.04
choco install wsl-ubuntu-2204 -y
# install docker desktop
choco install docker-desktop -y
# install gcloud SDK
choco install gcloudsdk --ignore-checksums -y
# install windows-sdk
choco install windows-sdk-10.1 -y
# install ngrok
choco install ngrok -y

# install Bitwarden
choco install bitwarden bitwarden-chrome bitwarden-cli -y


# install OneDrive
choco install onedrive -y
# install zoom
choco install zoom -y
# install LINE
choco install line --ignore-checksums -y
# install Kindle
choco install kindle -y
# install TeamViewer
choco install teamviewer -y
# install teamviewer.host
choco install teamviewer.host --ignore-checksums -y
# install wireshark
choco install wireshark -y
# install procmon
choco install procmon -y



# install Vim
choco install vim -y
# install curl
choco install curl -y
# install ExpressVPN
choco install expressvpn -y
# install vscode material icon theme
choco install materialicon-vscode -y
# install powertoys
choco install powertoys -y
# install gsudo
choco install gsudo -y
# install mingw
choco install mingw -y
# install winget
choco install winget -y
# install tree
choco install tree -y


# install choco cleaner
choco install choco-cleaner -y

# upgrade all packages
choco upgrade all -y

