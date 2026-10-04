param(
    [switch]$DryRun
)

# Mounts the Windows-side $HOME\workspace (see Set-Workspace.ps1) onto
# $HOME/workspace inside WSL, via ubuntu/wsl-setup/mount_workspace.sh (bind
# mount + /etc/fstab persistence, so it survives `wsl --shutdown`/reboot).
# After this, the Windows and WSL workspace directories are the same
# directory, instead of ubuntu/wsl-setup/set_workspace.sh's independent
# WSL-only ~/workspace.
#
# Same WSL-availability/path-conversion pattern as
# windows/installer/Setup-Wsl.ps1 (wsl wslpath to convert the Windows path,
# `wsl --` to run a command inside the default WSL distro).

Set-ExecutionPolicy Bypass -Scope Process -Force

# wsl.exe writes UTF-16LE when its stdout is piped/captured (not a real
# console) - decoding that as the default console codepage interleaves NUL
# bytes between characters, which silently breaks `-match`-based parsing of
# `wsl --list` further down. Set Unicode (UTF-16LE) explicitly to match what
# wsl.exe actually emits. (Different root cause from the bws UTF8 fix in
# Initialize-Security.ps1/Set-Aliases.ps1 - don't "fix" this back to UTF8.)
$OutputEncoding = [System.Text.Encoding]::Unicode
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode

$workspacePath = Join-Path -Path $HOME -ChildPath "workspace"
if (-not (Test-Path -Path $workspacePath)) {
    New-Item -Path $workspacePath -ItemType Directory -Force | Out-Null
    Write-Host "Workspace directory created at $workspacePath" -ForegroundColor Green
} else {
    Write-Host "Workspace directory already exists at $workspacePath" -ForegroundColor Yellow
}

if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Warning "WSL is not installed. Skipping workspace mount."
    return
}

$distros = wsl --list --quiet 2>$null | Where-Object { $_ -match "Ubuntu" }
if (-not $distros) {
    Write-Warning "No Ubuntu distro found in WSL. Run 'wsl --install -d Ubuntu' first."
    return
}

# PSScriptRoot = windows\settings\ -> repo root is 2 levels up
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$wslRepoRoot = (wsl wslpath ($repoRoot.Replace('\', '/'))).Trim()
$wslWorkspacePath = (wsl wslpath ($workspacePath.Replace('\', '/'))).Trim()
$wslSetupScript = "$wslRepoRoot/ubuntu/wsl-setup/setup.sh"

Write-Host "=== Mounting Windows workspace into WSL (~/workspace) ===" -ForegroundColor Cyan
Write-Host "Windows: $workspacePath"
Write-Host "WSL:     $wslWorkspacePath -> ~/workspace"

if ($DryRun) {
    Write-Host "[DRY RUN] wsl -- bash `"$wslSetupScript`" mount-workspace `"$wslWorkspacePath`"" -ForegroundColor Yellow
    return
}

wsl -- bash "$wslSetupScript" mount-workspace "$wslWorkspacePath"
