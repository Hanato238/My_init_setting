# Chocolateyがインストールされているか確認
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolateyがインストールされていません。先にChocolateyをインストールしてください。"
    return
}

# Python 3.9から13までをインストール
3.9..13 | ForEach-Object { choco install python -y --version $_ }
# VS Codeをインストール
choco install vscode -y
# Ubuntuをインストール
choco install wsl-ubuntu-2204 -y
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