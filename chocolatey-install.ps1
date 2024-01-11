# Install Chocolatey
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Verify installation
choco --version

# WSL2をインストール
choco install wsl2 -y
# Google Chromeをインストール
choco install googlechrome --ignore-checksums -y
# Google Driveをインストール
choco install google-drive-file-stream --ingnore-checksum -y

# 再起動
Restart-Computer
