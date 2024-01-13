# Run PowerShell as Administrator before executing this script

# Set execution policy to allow script execution
Set-ExecutionPolicy Bypass -Scope Process -Force; 

# Install Chocolatey
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Verify installation
choco --version

# WSL2をインストール
choco install wsl2 -y
# Google Chromeをインストール
choco install googlechrome -y
# Google Driveをインストール
choco install google-drive-file-stream -y

#再起動
Restart-Computer -Force