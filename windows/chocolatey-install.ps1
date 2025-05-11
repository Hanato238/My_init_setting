# Run PowerShell as Administrator before executing this script

# Set execution policy to allow script execution
Set-ExecutionPolicy Bypass -Scope Process -Force

# Install Chocolatey
# if Chocolatey is not installed, install it
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey is not installed, start installation..." -ForegroundColor Yellow

    Set-ExecutionPolicy Bypass -Scope Process -Force
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    Write-Host "Chocolatey install has been completed" -ForegroundColor Green
    return
}


# Verify installation
choco --version

# install Google Chrome
choco install googlechrome --ignore-checksums -y
# install Google Drive
choco install googledrie --ignore-checksums -y
choco install google-drive-file-stream --ignore-checksums -y
# install Git
choco install git -y