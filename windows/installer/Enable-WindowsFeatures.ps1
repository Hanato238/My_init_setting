param([switch]$DryRun)

Set-ExecutionPolicy Bypass -Scope Process -Force

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
