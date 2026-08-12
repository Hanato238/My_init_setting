param([switch]$Update, [switch]$DryRun, [string]$Profile = '', [switch]$IncludeLocalApps)

Set-ExecutionPolicy Bypass -Scope Process -Force

if ($Profile -eq 'Clinic') {
    . "$PSScriptRoot\packages\winget-packages-clinic.ps1"
    . "$PSScriptRoot\packages\choco-packages-clinic.ps1"
    $npmPackages = @()
    $uvToolPackages = @()
} else {
    . "$PSScriptRoot\packages\winget-packages.ps1"
    . "$PSScriptRoot\packages\choco-packages.ps1"
    . "$PSScriptRoot\packages\npm-packages.ps1"
    . "$PSScriptRoot\packages\uv-packages.ps1"
}

# --- winget ---
$wingetAction = if ($Update) { "Upgrading" } else { "Installing" }
Write-Host "$wingetAction apps via Winget..." -ForegroundColor Cyan
foreach ($pkg in $wingetPackages) {
    if ($DryRun) {
        $dryRunCmd = if ($Update) { "upgrade" } else { "install" }
        Write-Host "[DRY RUN] winget $dryRunCmd -e --id $pkg" -ForegroundColor Yellow
        continue
    }

    # winget upgrade errors out on a package that was never installed, so a
    # newly-added package still needs the install verb even during -Update.
    winget list -e --id $pkg --accept-source-agreements | Out-Null
    $isInstalled = $LASTEXITCODE -eq 0

    if ($isInstalled -and -not $Update) {
        Write-Host "$pkg is already installed, skipping." -ForegroundColor DarkGray
        continue
    }

    $wingetCmd = if ($isInstalled) { "upgrade" } else { "install" }
    $verb      = if ($isInstalled) { "Upgrading" } else { "Installing" }
    Write-Host "$verb $pkg..." -ForegroundColor Cyan
    winget $wingetCmd -e --id $pkg --accept-package-agreements --accept-source-agreements
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

$chocoTargets = $chocoPackages
if (-not $Update -and -not $DryRun) {
    $installedIds = (choco list --local-only -r) | ForEach-Object { ($_ -split '\|')[0] }
    $chocoTargets = $chocoPackages | Where-Object { $_ -notin $installedIds }
    foreach ($pkg in ($chocoPackages | Where-Object { $_ -in $installedIds })) {
        Write-Host "$pkg is already installed, skipping." -ForegroundColor DarkGray
    }
}

if ($DryRun) {
    $chocoPackages | ForEach-Object { Write-Host "[DRY RUN] choco $chocoCmd $_" -ForegroundColor Yellow }
} elseif ($chocoTargets.Count -gt 0) {
    choco $chocoCmd @chocoTargets --ignore-checksums -y
} else {
    Write-Host "No new Chocolatey packages to install." -ForegroundColor DarkGray
}
Write-Host "$chocoAction via Chocolatey has been finished"

# --- Local (non-community) Chocolatey packages ---
# Packages under packages\local\<id>\ are internal/custom apps not published to the
# Chocolatey community repository (proprietary installers, private tools, etc.). Each
# subfolder holds only a .nuspec + tools\*.ps1 (no bundled binaries - those are downloaded
# at install time, or looked up in an external asset location; see
# packages\local\README.md). Opt-in via -IncludeLocalApps since some of these packages
# (e.g. bartender) require assets to be staged on the machine beforehand.
if ($IncludeLocalApps) {
    $localPackagesDir = Join-Path $PSScriptRoot 'packages\local'
    $localPackageFolders = if (Test-Path $localPackagesDir) { Get-ChildItem -Path $localPackagesDir -Directory } else { @() }

    if ($localPackageFolders.Count -gt 0) {
        Write-Host "$chocoAction local apps via Chocolatey..." -ForegroundColor Cyan
        $localFeedDir = Join-Path $env:TEMP 'choco-local-feed'
        if (-not $DryRun) { New-Item -ItemType Directory -Path $localFeedDir -Force | Out-Null }

        foreach ($pkgDir in $localPackageFolders) {
            $nuspec = Get-ChildItem -Path $pkgDir.FullName -Filter '*.nuspec' | Select-Object -First 1
            if (-not $nuspec) {
                Write-Warning "No .nuspec found in $($pkgDir.FullName), skipping."
                continue
            }
            $pkgId = $nuspec.BaseName
            if ($DryRun) {
                Write-Host "[DRY RUN] choco pack `"$($nuspec.FullName)`" --outputdirectory `"$localFeedDir`"" -ForegroundColor Yellow
                Write-Host "[DRY RUN] choco $chocoCmd $pkgId -s `"$localFeedDir`" -y --ignore-checksums" -ForegroundColor Yellow
            } else {
                choco pack "$($nuspec.FullName)" --outputdirectory "$localFeedDir"
                choco $chocoCmd $pkgId -s "$localFeedDir" -y --ignore-checksums
            }
        }
        Write-Host "$chocoAction local apps via Chocolatey has been finished"
    }
} else {
    Write-Host "Skipping local apps (use -IncludeLocalApps to install bartender/orca)." -ForegroundColor DarkGray
}

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
# npm update -g skips packages that were never installed, but plain
# npm install -g always resolves to the latest version (installing new
# packages and upgrading existing ones), so it is used for both cases.
if ($npmPackages.Count -gt 0) {
    $npmAction = if ($Update) { "Upgrading" } else { "Installing" }
    Write-Host "$npmAction global npm packages..." -ForegroundColor Cyan
    if ($DryRun) {
        $npmPackages | ForEach-Object { Write-Host "[DRY RUN] npm install -g $_" -ForegroundColor Yellow }
    } else {
        npm install -g @npmPackages
    }
}

# --- uv tool packages ---
# uv tool upgrade errors out on a tool that was never installed, so install
# runs first (a no-op if already present) and upgrade follows only on -Update.
if ($uvToolPackages.Count -gt 0) {
    $uvAction = if ($Update) { "Upgrading" } else { "Installing" }
    Write-Host "$uvAction uv tools..." -ForegroundColor Cyan
    foreach ($pkg in $uvToolPackages) {
        if ($DryRun) {
            Write-Host "[DRY RUN] uv tool install $pkg" -ForegroundColor Yellow
            if ($Update) { Write-Host "[DRY RUN] uv tool upgrade $pkg" -ForegroundColor Yellow }
            continue
        }
        uv tool install $pkg
        if ($Update) { uv tool upgrade $pkg }
    }
}
