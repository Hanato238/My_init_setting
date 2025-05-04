# Run PowerShell as Administrator before executing this script

# Set execution policy to allow script execution
##? Set-ExecutionPolicy Bypass -Scope Process -Force; 

# Install Chocolatey
# Chocolateyがインストールされているか確認
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
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