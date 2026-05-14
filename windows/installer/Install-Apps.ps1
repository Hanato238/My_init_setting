Set-ExecutionPolicy Bypass -Scope Process -Force

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey is not installed. Please install Chocolatey first." -ForegroundColor Red
    return
}

# Install all packages in one command
Write-Host "Installing apps via Chocolatey..." -ForegroundColor Cyan
choco install googlechrome googledrive google-drive-file-stream gcloudsdk python39 python310 python311 python312 python313 python314 vim curl gsudo mingw winget tree procmon wireshark powertoys expressvpn uv jq git nodejs-lts vscode materialicon-vscode ngrok wsl-ubuntu-2204 docker-desktop windows-sdk-10.1 awscli bitwarden bitwarden-chrome bitwarden-cli spacedesk-server choco-cleaner --ignore-checksums -y

# upgrade all packages
choco upgrade all -y

# Setup PowerShell Secret Management
Write-Host "Installing PowerShell modules..." -ForegroundColor Cyan
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force

# install cli tools via npm
Write-Host "Installing global npm packages..." -ForegroundColor Cyan
npm install -g @anthropic-ai/claude-code @anthropic-ai/sdk @google/gemini-cli
