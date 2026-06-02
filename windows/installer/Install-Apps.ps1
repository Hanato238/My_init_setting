param([switch]$DryRun)

Set-ExecutionPolicy Bypass -Scope Process -Force

. "$PSScriptRoot\packages\winget-packages.ps1"
. "$PSScriptRoot\packages\choco-packages.ps1"
. "$PSScriptRoot\packages\npm-packages.ps1"

# --- winget (includes Chocolatey) ---
Write-Host "Installing apps via Winget..." -ForegroundColor Cyan
foreach ($pkg in $wingetPackages) {
    if ($DryRun) {
        Write-Host "[DRY RUN] winget install -e --id $pkg" -ForegroundColor Yellow
    } else {
        Write-Host "Installing $pkg..." -ForegroundColor Cyan
        winget install -e --id $pkg --accept-package-agreements --accept-source-agreements
    }
}
Write-Host "Installation via Winget has been finished"

# Refresh PATH and nvm env vars so subsequent commands can find nvm/choco
if (-not $DryRun) {
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH    = "$machinePath;$userPath"
    foreach ($var in @("NVM_HOME", "NVM_SYMLINK")) {
        $val = [System.Environment]::GetEnvironmentVariable($var, "Machine")
        if ($val) { [System.Environment]::SetEnvironmentVariable($var, $val, "Process") }
    }
}

# --- Chocolatey ---
Write-Host "Installing apps via Chocolatey..." -ForegroundColor Cyan
if ($DryRun) {
    $chocoPackages | ForEach-Object { Write-Host "[DRY RUN] choco install $_" -ForegroundColor Yellow }
} else {
    choco install @chocoPackages --ignore-checksums -y
}
Write-Host "Installation via Chocolatey has been finished"

# --- PowerShell modules ---
Write-Host "Installing PowerShell modules..." -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "[DRY RUN] Install-Module Microsoft.PowerShell.SecretManagement" -ForegroundColor Yellow
    Write-Host "[DRY RUN] Install-Module Microsoft.PowerShell.SecretStore" -ForegroundColor Yellow
    Write-Host "[DRY RUN] Register-SecretVault -Name LocalStore" -ForegroundColor Yellow
} else {
    Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
    Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force
    Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
}

# --- Node.js via nvm ---
$nodeVersion = "22"
Write-Host "Installing Node.js $nodeVersion via nvm..." -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "[DRY RUN] nvm install $nodeVersion" -ForegroundColor Yellow
    Write-Host "[DRY RUN] nvm use $nodeVersion" -ForegroundColor Yellow
} else {
    nvm install $nodeVersion
    nvm use $nodeVersion
    # Refresh PATH again so nvm-managed npm is in scope
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

# --- npm global packages ---
Write-Host "Installing global npm packages..." -ForegroundColor Cyan
if ($DryRun) {
    $npmPackages | ForEach-Object { Write-Host "[DRY RUN] npm install -g $_" -ForegroundColor Yellow }
} else {
    npm install -g @npmPackages
}
