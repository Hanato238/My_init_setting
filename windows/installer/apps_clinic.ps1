# Chocolateyがインストールされているか確認
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

# install zoom
choco install zoom -y
# install LINE
choco install line -y
# install teamviewer.host
choco install teamviewer.host --ignore-checksums -y

# install vim
choco install vim -y
# install curl
choco install curl -y
# install ExpressVPN
choco install expressvpn -y
# install powertoys
choco install powertoys -y


# upgrade all
choco upgrade all -y



