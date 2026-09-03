param([switch]$DryRun)

Set-ExecutionPolicy Bypass -Scope Process -Force

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrative privileges required. Elevating..." -ForegroundColor Yellow
    $dryRunArg = if ($DryRun) { ' -DryRun' } else { '' }
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"$dryRunArg" -Verb RunAs
    return
}

# === Windows Optional Features ===
Write-Host "[ Windows Features ]" -ForegroundColor Cyan

$features = @(
    @{ Name = "Containers-DisposableClientVM"; Label = "Windows Sandbox" }
)

$needRestart = $false

foreach ($f in $features) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $f.Name -ErrorAction SilentlyContinue).State
    if ($state -eq "Enabled") {
        Write-Host "$($f.Label) is already enabled." -ForegroundColor Green
        continue
    }
    if ($DryRun) {
        Write-Host "[DRY RUN] Enable-WindowsOptionalFeature: $($f.Label)" -ForegroundColor Yellow
    } else {
        Write-Host "Enabling $($f.Label)..." -ForegroundColor Cyan
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $f.Name -All -NoRestart
        if ($result.RestartNeeded) { $needRestart = $true }
        Write-Host "$($f.Label) enabled." -ForegroundColor Green
    }
}

if ($needRestart) {
    Write-Host ""
    Write-Host "[NOTICE] A restart is required for the changes to take effect." -ForegroundColor Yellow
    Write-Host "Please restart Windows and re-run Start-Setup.ps1 to continue." -ForegroundColor Yellow
}

Write-Host ""

# === Desktop Environment & Taskbar ===
& "$PSScriptRoot\Clear-DesktopTaskbar.ps1" -DryRun:$DryRun

Write-Host ""

# === Docker Desktop ===
Write-Host "[ Docker Desktop ]" -ForegroundColor Cyan

$dockerSettingsPath = "$env:APPDATA\Docker\settings-store.json"

if (-not (Test-Path $dockerSettingsPath)) {
    Write-Warning "Docker Desktop settings file not found. Is Docker Desktop installed?"
} else {
    $settings = Get-Content $dockerSettingsPath | ConvertFrom-Json

    if ($null -eq $settings.IntegratedWslDistros) {
        $settings | Add-Member -MemberType NoteProperty -Name "IntegratedWslDistros" -Value @()
    }

    $targetDistros = @("Ubuntu")
    $changed = $false
    foreach ($distro in $targetDistros) {
        if ($settings.IntegratedWslDistros -contains $distro) {
            Write-Host "$distro already in WSL Integration." -ForegroundColor Gray
            continue
        }
        if ($DryRun) {
            Write-Host "[DRY RUN] Add $distro to Docker WSL Integration" -ForegroundColor Yellow
        } else {
            $settings.IntegratedWslDistros += $distro
            Write-Host "Added $distro to WSL Integration." -ForegroundColor Green
            $changed = $true
        }
    }

    if ($changed) {
        $settings | ConvertTo-Json -Depth 10 | Set-Content $dockerSettingsPath
        Write-Host "Docker Desktop settings updated. Please restart Docker Desktop." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Done: Windows settings configured." -ForegroundColor Green
