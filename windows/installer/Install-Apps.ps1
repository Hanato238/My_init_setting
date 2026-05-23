Set-ExecutionPolicy Bypass -Scope Process -Force

Write-Host "Installing apps via Winget..."

$wingetPackages = @(
    "Google.Chrome",
    "Google.GoogleDrive",
    "Google.CloudSDK",
    "Python.Python.3.9",
    "Python.Python.3.10",
    "Python.Python.3.11",
    "Python.Python.3.12",
    "Python.Python.3.13",
    "vim.vim",
    "cURL.cURL",
    "gerardog.gsudo",
    "MSYS2.MSYS2",
    "GnuWin32.Tree",
    "Microsoft.Sysinternals.ProcessMonitor",
    "WiresharkFoundation.Wireshark",
    "Microsoft.PowerToys",
    "ExpressVPN.ExpressVPN",
    "astral-sh.uv",
    "jqlang.jq",
    "Git.Git",
    "GitHub.cli",
    "OpenJS.NodeJS.LTS",
    "CoreyButler.NVMforWindows",
    "Microsoft.VisualStudioCode",
    "Ngrok.Ngrok",
    "Microsoft.WSL.PreRelease",
    "Canonical.Ubuntu.2404",
    "Docker.DockerDesktop",
    "Docker.DockerCLI",
    "Docker.sbx",
    "Rustlang.Rustup",
    "Microsoft.WindowsSDK",
    "Amazon.AWSCLI",
    "Bitwarden.Bitwarden",
    "Bitwarden.CLI",
    "Telegram.TelegramDesktop",
    "Microsoft.WindowsTerminal"
    "Doist.Todoist"
)

foreach ($pkg in $wingetPackages) {
    Write-Host "Installing $pkg..." -ForegroundColor Cyan
    winget install -e --id $pkg --accept-package-agreements --accept-source-agreements
}

Write-Host "Installation via Winget has been finished"

# Check if Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey is not installed. Please install Chocolatey first." -ForegroundColor Red
    return
}

# Install all packages in one command
Write-Host "Installing apps via Chocolatey..." -ForegroundColor Cyan
choco install materialicon-vscode bitwarden-chrome spacedesk-server --ignore-checksums -y
# upgrade all packages
# choco upgrade all -y
Write-Host "Installation via Chocolatey has been finished"


# Setup PowerShell Secret Management
Write-Host "Installing PowerShell modules..." -ForegroundColor Cyan
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force

# install cli tools via npm
Write-Host "Installing global npm packages..." -ForegroundColor Cyan
npm install -g @anthropic-ai/claude-code @anthropic-ai/sdk @google/gemini-cli
