param(
    [string]$Category = "all",
    [switch]$Update,
    [switch]$DryRun
)

# PSScriptRoot = windows\installer\ -> repo root is 2 levels up
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Convert Windows path to WSL-accessible path (e.g. /mnt/c/Users/...)
$wslRepoRoot = (wsl wslpath ($repoRoot.Replace('\', '/'))).Trim()
$wslSetupScript = "$wslRepoRoot/ubuntu/setup.sh"

# Check WSL availability
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Warning "WSL is not installed. Skipping Ubuntu setup."
    return
}

# Check Ubuntu distro
$distros = wsl --list --quiet 2>$null | Where-Object { $_ -match "Ubuntu" }
if (-not $distros) {
    Write-Warning "No Ubuntu distro found in WSL. Run 'wsl --install -d Ubuntu' first."
    return
}

$effectiveCategory = if ($Update) { "update" } else { $Category }

Write-Host "=== Setting up Ubuntu on WSL (category: $effectiveCategory) ===" -ForegroundColor Cyan
Write-Host "Repo (WSL path): $wslSetupScript" -ForegroundColor Gray

if ($DryRun) {
    Write-Host "[DRY RUN] wsl -- bash `"$wslSetupScript`" $effectiveCategory" -ForegroundColor Yellow
    return
}

wsl -- bash "$wslSetupScript" $effectiveCategory
