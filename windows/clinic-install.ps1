# Chocolateyがインストールされているか確認
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolateyがインストールされていません。先にChocolateyをインストールしてください。"
    return
}

# zoomをインストール
choco install zoom -y
# LINEをインストール
choco install line -y
# teamviewer.hostをインストール
choco install teamviewer.host -y

# Vimをインストール
choco install vim -y
# Curlをインストール
choco install curl -y
# ExpressVPNをインストール
choco install expressvpn -y
# powertoysをインストール
choco install powertoys -y


# すべてのアプリをupgrade
chogo upgrade all -y



