Set-ExecutionPolicy Bypass -Scope Process -Force

. "$PSScriptRoot\packages\winget-packages.ps1"
. "$PSScriptRoot\packages\choco-packages.ps1"
. "$PSScriptRoot\packages\npm-packages.ps1"

# --- winget (includes Chocolatey) ---
Write-Host "Installing apps via Winget..." -ForegroundColor Cyan
foreach ($pkg in $wingetPackages) {
    Write-Host "Installing $pkg..." -ForegroundColor Cyan
    winget install -e --id $pkg --accept-package-agreements --accept-source-agreements
}
Write-Host "Installation via Winget has been finished"

# Refresh PATH and nvm env vars so subsequent commands can find nvm/choco
$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
$userPath    = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$env:PATH    = "$machinePath;$userPath"
foreach ($var in @("NVM_HOME", "NVM_SYMLINK")) {
    $val = [System.Environment]::GetEnvironmentVariable($var, "Machine")
    if ($val) { [System.Environment]::SetEnvironmentVariable($var, $val, "Process") }
}

# --- Chocolatey ---
Write-Host "Installing apps via Chocolatey..." -ForegroundColor Cyan
choco install @chocoPackages --ignore-checksums -y
Write-Host "Installation via Chocolatey has been finished"

# --- PowerShell modules ---
Write-Host "Installing PowerShell modules..." -ForegroundColor Cyan
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force
Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault

# --- Node.js via nvm ---
$nodeVersion = "22"
Write-Host "Installing Node.js $nodeVersion via nvm..." -ForegroundColor Cyan
nvm install $nodeVersion
nvm use $nodeVersion

# Refresh PATH again so nvm-managed npm is in scope
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH", "User")

# --- npm global packages ---
Write-Host "Installing global npm packages..." -ForegroundColor Cyan
npm install -g @npmPackages
