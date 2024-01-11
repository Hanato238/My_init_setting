# Chocolateyがインストールされているか確認
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolateyがインストールされていません。先にChocolateyをインストールしてください。"
    return
}


# Vimをインストール
choco install vim -y
# Curlをインストール
choco install curl -y
# Gitをインストール
choco install git -y