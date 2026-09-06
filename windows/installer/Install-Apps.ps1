param([switch]$Update, [switch]$DryRun, [string]$Profile = '', [switch]$IncludeLocalApps,
      [switch]$Prune, [switch]$Force)

Set-ExecutionPolicy Bypass -Scope Process -Force

# --- Managed-package manifest ---
# Records the exact package lists applied on the last successful (non-DryRun) run so
# that -Prune can tell which packages this script previously managed but that have
# since been removed from the list files. Lives next to Start-Setup.ps1's
# install-profile.txt.
$manifestFile = "$env:LOCALAPPDATA\MyInitSetting\installed-manifest.json"

# Pure helper (no side effects) so it can be unit-tested: returns, per manager, the
# IDs present in $Previous but absent from $Current.
function Get-PrunePlan {
    param([hashtable]$Previous, [hashtable]$Current)
    $plan = @{}
    foreach ($mgr in 'winget', 'choco', 'npm', 'uv', 'cargo') {
        $old = @($Previous[$mgr])
        $new = @($Current[$mgr])
        $plan[$mgr] = @($old | Where-Object { $_ -and ($_ -notin $new) })
    }
    return $plan
}

function Read-InstalledManifest {
    if (-not (Test-Path $manifestFile)) { return $null }
    try {
        return Get-Content $manifestFile -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Could not parse manifest ${manifestFile}: $_"
        return $null
    }
}

function Save-InstalledManifest {
    param([hashtable]$Lists, [string]$ProfileName)
    if ($DryRun) { return }
    $dir = Split-Path $manifestFile
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $payload = [ordered]@{
        profile   = $ProfileName
        updatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        winget    = @($Lists.winget)
        choco     = @($Lists.choco)
        npm       = @($Lists.npm)
        uv        = @($Lists.uv)
        cargo     = @($Lists.cargo)
    }
    $payload | ConvertTo-Json | Set-Content -Path $manifestFile -Encoding UTF8
}

if ($Profile -eq 'Clinic') {
    . "$PSScriptRoot\packages\winget-packages-clinic.ps1"
    . "$PSScriptRoot\packages\choco-packages-clinic.ps1"
    $npmPackages = @()
    $uvToolPackages = @()
    $cargoPackages = @()
} else {
    . "$PSScriptRoot\packages\winget-packages.ps1"
    . "$PSScriptRoot\packages\choco-packages.ps1"
    . "$PSScriptRoot\packages\npm-packages.ps1"
    . "$PSScriptRoot\packages\uv-packages.ps1"
    . "$PSScriptRoot\packages\cargo-packages.ps1"
}

$effectiveProfile = if ($Profile -eq 'Clinic') { 'Clinic' } else { 'Default' }
$currentLists = @{
    winget = @($wingetPackages)
    choco  = @($chocoPackages)
    npm    = @($npmPackages)
    uv     = @($uvToolPackages)
    cargo  = @($cargoPackages)
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
    # rustup (Rustlang.Rustup) drops cargo here but only adds it to PATH for new shells.
    $cargoBin = "$env:USERPROFILE\.cargo\bin"
    if ((Test-Path $cargoBin) -and ($env:PATH -notlike "*$cargoBin*")) {
        $env:PATH = "$env:PATH;$cargoBin"
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

# --- cargo packages ---
# `cargo install` always builds the latest published version, so it doubles as
# the install and the upgrade path. Skipped when cargo is not on PATH (rustup
# missing / shell not reopened). Crates like bws compile from source and need
# the MSVC linker in addition to the Rust toolchain - installed via the choco
# list (visualstudio2022-workload-vctools).
if ($cargoPackages.Count -gt 0) {
    $cargoAction = if ($Update) { "Upgrading" } else { "Installing" }
    Write-Host "$cargoAction cargo packages..." -ForegroundColor Cyan
    if ($DryRun) {
        $cargoPackages | ForEach-Object { Write-Host "[DRY RUN] cargo install $_ --locked" -ForegroundColor Yellow }
    } elseif (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        Write-Warning "cargo not found on PATH; skipping cargo packages. Install Rustlang.Rustup (+ the choco VC++ build tools) and reopen the shell."
    } else {
        $installedCrates = cargo install --list
        foreach ($pkg in $cargoPackages) {
            $isInstalled = [bool]($installedCrates | Where-Object { $_ -match "^$([regex]::Escape($pkg)) v" })
            if ($isInstalled -and -not $Update) {
                Write-Host "$pkg is already installed, skipping." -ForegroundColor DarkGray
                continue
            }
            cargo install $pkg --locked
        }
    }
}

# --- Reconcile: remove packages dropped from the lists ---
# Only touches packages this script previously recorded as managed (in the
# manifest) that are no longer present in the current list files. Manual apps and
# anything not in the manifest are never considered. Opt-in via -Prune.
$pruneResults = @()
function Add-PruneResult([string]$Pkg, [string]$Status, [string]$Message) {
    $script:pruneResults += @{ Pkg = $Pkg; Status = $Status; Message = $Message }
}

function Test-PackageInstalled([string]$Manager, [string]$Id) {
    switch ($Manager) {
        'winget' {
            winget list -e --id $Id --accept-source-agreements | Out-Null
            return $LASTEXITCODE -eq 0
        }
        'choco' {
            $installedIds = (choco list --local-only -r) | ForEach-Object { ($_ -split '\|')[0] }
            return $Id -in $installedIds
        }
        'npm' {
            npm ls -g --depth=0 $Id 2>&1 | Out-Null
            return $LASTEXITCODE -eq 0
        }
        'uv' {
            $tools = uv tool list 2>$null
            return [bool]($tools | Where-Object { $_ -match "^$([regex]::Escape($Id))(\s|$)" })
        }
        'cargo' {
            if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) { return $false }
            $crates = cargo install --list 2>$null
            return [bool]($crates | Where-Object { $_ -match "^$([regex]::Escape($Id)) v" })
        }
    }
    return $false
}

function Invoke-PackageUninstall([string]$Manager, [string]$Id) {
    switch ($Manager) {
        'winget' { winget uninstall -e --id $Id --accept-source-agreements }
        'choco'  { choco uninstall $Id -y }
        'npm'    { npm uninstall -g $Id }
        'uv'     { uv tool uninstall $Id }
        'cargo'  { cargo uninstall $Id }
    }
}

if ($Prune) {
    Write-Host "`nReconciling installed packages against the lists..." -ForegroundColor Cyan
    $manifest = Read-InstalledManifest

    if ($null -eq $manifest) {
        Write-Host "No manifest found - recording current state, nothing to prune on first run." -ForegroundColor DarkGray
    } elseif ($manifest.profile -and $manifest.profile -ne $effectiveProfile) {
        Write-Warning "Manifest profile '$($manifest.profile)' differs from current '$effectiveProfile'; skipping prune. Re-run -Prune to reconcile against the new profile."
    } else {
        $previousLists = @{
            winget = @($manifest.winget)
            choco  = @($manifest.choco)
            npm    = @($manifest.npm)
            uv     = @($manifest.uv)
            cargo  = @($manifest.cargo)
        }
        $plan = Get-PrunePlan -Previous $previousLists -Current $currentLists
        $totalToRemove = @($plan.Values | ForEach-Object { $_ }).Count

        if ($totalToRemove -eq 0) {
            Write-Host "Nothing to prune - installed set already matches the lists." -ForegroundColor DarkGray
        }

        foreach ($mgr in 'winget', 'choco', 'npm', 'uv', 'cargo') {
            foreach ($pkg in $plan[$mgr]) {
                if (-not (Test-PackageInstalled $mgr $pkg)) {
                    Write-Host "$pkg ($mgr) already absent, skipping." -ForegroundColor DarkGray
                    Add-PruneResult $pkg 'SKIP' 'already absent'
                    continue
                }
                if ($DryRun) {
                    switch ($mgr) {
                        'winget' { Write-Host "[DRY RUN] winget uninstall -e --id $pkg" -ForegroundColor Yellow }
                        'choco'  { Write-Host "[DRY RUN] choco uninstall $pkg -y" -ForegroundColor Yellow }
                        'npm'    { Write-Host "[DRY RUN] npm uninstall -g $pkg" -ForegroundColor Yellow }
                        'uv'     { Write-Host "[DRY RUN] uv tool uninstall $pkg" -ForegroundColor Yellow }
                        'cargo'  { Write-Host "[DRY RUN] cargo uninstall $pkg" -ForegroundColor Yellow }
                    }
                    Add-PruneResult $pkg 'DRYRUN' "$mgr"
                    continue
                }
                if (-not $Force) {
                    $answer = Read-Host "Uninstall $pkg ($mgr)? [y/N]"
                    if ($answer -notmatch '^(y|yes)$') {
                        Write-Host "Keeping $pkg." -ForegroundColor DarkGray
                        Add-PruneResult $pkg 'SKIP' 'declined'
                        continue
                    }
                }
                Write-Host "Uninstalling $pkg ($mgr)..." -ForegroundColor Cyan
                try {
                    Invoke-PackageUninstall $mgr $pkg
                    Add-PruneResult $pkg 'OK' "removed via $mgr"
                } catch {
                    Write-Warning "Failed to uninstall ${pkg}: $_"
                    Add-PruneResult $pkg 'ERR' $_.Exception.Message
                }
            }
        }

        if ($pruneResults.Count -gt 0) {
            Write-Host "`n=== Prune Summary ===" -ForegroundColor Cyan
            foreach ($r in $pruneResults) {
                $color = 'White'
                if ($r.Status -eq 'OK')     { $color = 'Green' }
                if ($r.Status -eq 'SKIP')   { $color = 'DarkGray' }
                if ($r.Status -eq 'DRYRUN') { $color = 'Yellow' }
                if ($r.Status -eq 'ERR')    { $color = 'Red' }
                $msg = if ($r.Message) { "  - $($r.Message)" } else { '' }
                Write-Host ("[$($r.Status)]".PadRight(9) + "$($r.Pkg)$msg") -ForegroundColor $color
            }
        }
    }
}

# --- Save the managed-package manifest ---
# Always reflects the state this run converged to, so the next -Prune knows what
# was previously managed.
Save-InstalledManifest -Lists $currentLists -ProfileName $effectiveProfile
