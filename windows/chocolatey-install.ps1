# Run PowerShell as Administrator before executing this script

# Set execution policy to allow script execution
Set-ExecutionPolicy Bypass -Scope Process -Force; 

# Install Chocolatey
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Verify installation
choco --version

# Google Chromeをインストール
choco install googlechrome -y
# Google Driveをインストール
choco install google-drive-file-stream -y
# Gitをインストール
choco install git -y


#再起動
Restart-Computer -Force