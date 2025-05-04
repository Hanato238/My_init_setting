# Run PowerShell as Administrator before executing this script

# Set execution policy to allow script execution
##? Set-ExecutionPolicy Bypass -Scope Process -Force; 

# Install Chocolatey
# Chocolateyが存在しない場合、インストールして終了
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey が見つかりません。インストールを開始します..." -ForegroundColor Yellow

    Set-ExecutionPolicy Bypass -Scope Process -Force
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    Write-Host "Chocolatey install has been completed" -ForegroundColor Green
    return
}


# Verify installation
choco --version

# Google Chromeをインストール
choco install googlechrome --ignore-checksums -y
# Google Driveをインストール
choco install googledrie --ignore-checksums -y
choco install google-drive-file-stream --ignore-checksums -y
# Gitをインストール
choco install git -y


#再起動
Restart-Computer -Force