Set-ExecutionPolicy Bypass -Scope Process -Force

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey is not installed. Please install Chocolatey first." -ForegroundColor Red
    return
}

# install Google Chrome
choco install googlechrome --ignore-checksums -y
# install Google Drive
choco install googledrie --ignore-checksums -y
choco install google-drive-file-stream --ignore-checksums -y
# install Git
choco install git -y

# install python 3.9, 3.10, 3.11, 3.12, 3.13
choco install python39 python310 pytnon311 python312 python313 -y
# install vscode
choco install vscode -y
# install ubuntu 22.04
choco install wsl-ubuntu-2204 -y
# install docker desktop
choco install docker-desktop -y



# install OneDrive
choco install onedrive -y
# install zoom
choco install zoom -y
# install LINE
choco install line --ignore-checksums -y
# install VMware Workstation
choco install vmware-workstation-player -y
# install Kindle
choco install kindle -y
# install TeamViewer
choco install teamviewer -y
# install teamviewer.host
choco install teamviewer.host --ignore-checksums -y



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


# upgrade all packages
choco upgrade all -y



# 