param(
    [string]$Category = "all",
    [switch]$Update,
    [switch]$DryRun
)

# wsl.exe writes UTF-16LE when its stdout is piped/captured (not a real
# console) - decoding that as the default console codepage interleaves NUL
# bytes between characters, which silently breaks `-match`-based parsing of
# `wsl --list` further down. Set Unicode (UTF-16LE) explicitly to match what
# wsl.exe actually emits. (Different root cause from the bws UTF8 fix in
# Initialize-Security.ps1/Set-Aliases.ps1 - don't "fix" this back to UTF8.)
$OutputEncoding = [System.Text.Encoding]::Unicode
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode

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
