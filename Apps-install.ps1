# Chocolateyがインストールされているか確認
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolateyがインストールされていません。先にChocolateyをインストールしてください"
    return
}

# Python 3.9から12, vscodeをパスを指定してインストール
choco install python python39 python310 python311 vscode -y --install-arguments="'/InstallLocation=C:\Users\lesen\AppData\Local\Programs"
# Ubuntuをインストール
choco install wsl-ubuntu-2204 -y
# WSL2をインストール
choco install wsl2 -y
# docker desktopをインストール
choco install docker-desktop -y


# OneDriveをインストール
choco install onedrive -y
# Prime Videoアプリをインストール
choco install prime-video-desktop -y
# zoomをインストール
choco install zoom -y
# LINEをインストール
choco install line -y
# VMware workstationをインストール
choco install vmware-workstation-player -y
# kindleをインストール
choco install kindle -y

# Vimをインストール
choco install vim -y
# Curlをインストール
choco install curl -y
# Gitをインストール
choco install git -y
# ExpressVPNをインストール
choco install expressvpn -y
# material iconをインストール
choco install Materialico-vscode -y
# powertoysをインストール
choco install powertoys -y
