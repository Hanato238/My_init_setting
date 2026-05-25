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
    "Microsoft.WindowsTerminal",
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

# Refresh PATH and nvm env vars in current session after winget installs
$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
$userPath    = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$env:PATH    = "$machinePath;$userPath"
foreach ($var in @("NVM_HOME", "NVM_SYMLINK")) {
    $val = [System.Environment]::GetEnvironmentVariable($var, "Machine")
    if ($val) { [System.Environment]::SetEnvironmentVariable($var, $val, "Process") }
}

# Install and activate Node.js via nvm
$nodeVersion = "22"
Write-Host "Installing Node.js $nodeVersion via nvm..." -ForegroundColor Cyan
nvm install $nodeVersion
nvm use $nodeVersion

# Refresh PATH again so nvm-managed npm is in scope
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH", "User")

# install cli tools via npm
Write-Host "Installing global npm packages..." -ForegroundColor Cyan
npm install -g @anthropic-ai/claude-code @anthropic-ai/sdk @google/gemini-cli
