param([switch]$Update, [switch]$DryRun)

Set-ExecutionPolicy Bypass -Scope Process -Force

. "$PSScriptRoot\packages\winget-packages.ps1"
. "$PSScriptRoot\packages\choco-packages.ps1"
. "$PSScriptRoot\packages\npm-packages.ps1"

# --- winget ---
$wingetAction = if ($Update) { "Upgrading" } else { "Installing" }
$wingetCmd    = if ($Update) { "upgrade" }   else { "install" }
Write-Host "$wingetAction apps via Winget..." -ForegroundColor Cyan
foreach ($pkg in $wingetPackages) {
    if ($DryRun) {
        Write-Host "[DRY RUN] winget $wingetCmd -e --id $pkg" -ForegroundColor Yellow
    } else {
        Write-Host "$wingetAction $pkg..." -ForegroundColor Cyan
        winget $wingetCmd -e --id $pkg --accept-package-agreements --accept-source-agreements
    }
}
Write-Host "$wingetAction via Winget has been finished"

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
$chocoAction = if ($Update) { "Upgrading" } else { "Installing" }
$chocoCmd    = if ($Update) { "upgrade" }   else { "install" }
Write-Host "$chocoAction apps via Chocolatey..." -ForegroundColor Cyan
if ($DryRun) {
    $chocoPackages | ForEach-Object { Write-Host "[DRY RUN] choco $chocoCmd $_" -ForegroundColor Yellow }
} else {
    choco $chocoCmd @chocoPackages --ignore-checksums -y
}
Write-Host "$chocoAction via Chocolatey has been finished"

# --- PowerShell modules ---
Write-Host "$(if ($Update) { 'Updating' } else { 'Installing' }) PowerShell modules..." -ForegroundColor Cyan
if ($DryRun) {
    if ($Update) {
        Write-Host "[DRY RUN] Update-Module Microsoft.PowerShell.SecretManagement" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Update-Module Microsoft.PowerShell.SecretStore" -ForegroundColor Yellow
    } else {
        Write-Host "[DRY RUN] Install-Module Microsoft.PowerShell.SecretManagement" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Install-Module Microsoft.PowerShell.SecretStore" -ForegroundColor Yellow
        Write-Host "[DRY RUN] Register-SecretVault -Name LocalStore" -ForegroundColor Yellow
    }
} elseif ($Update) {
    Update-Module Microsoft.PowerShell.SecretManagement -Force
    Update-Module Microsoft.PowerShell.SecretStore -Force
} else {
    Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
    Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force
    Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
}

# --- Node.js via nvm ---
$nodeVersion = "22"
Write-Host "$(if ($Update) { 'Restoring' } else { 'Installing' }) Node.js $nodeVersion via nvm..." -ForegroundColor Cyan
if ($DryRun) {
    if (-not $Update) { Write-Host "[DRY RUN] nvm install $nodeVersion" -ForegroundColor Yellow }
    Write-Host "[DRY RUN] nvm use $nodeVersion" -ForegroundColor Yellow
} else {
    if (-not $Update) { nvm install $nodeVersion }
    nvm use $nodeVersion
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
