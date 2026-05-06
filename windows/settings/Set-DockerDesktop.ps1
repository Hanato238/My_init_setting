# Docker Desktop WSL Integration Setup
# This script enables WSL integration for specified distributions in Docker Desktop settings.

$settingsPath = "$env:APPDATA\Docker\settings-store.json"

if (Test-Path $settingsPath) {
    Write-Host "Updating Docker Desktop settings at $settingsPath..." -ForegroundColor Cyan
    
    # Read the settings file
    $settings = Get-Content $settingsPath | ConvertFrom-Json
    
    # Ensure IntegratedWslDistros exists and is an array
    if ($null -eq $settings.IntegratedWslDistros) {
        $settings | Add-Member -MemberType NoteProperty -Name "IntegratedWslDistros" -Value @()
    }

    # Define target distributions (e.g., Ubuntu)
    $targetDistros = @("Ubuntu")

    $changed = $false
    foreach ($distro in $targetDistros) {
        if ($settings.IntegratedWslDistros -notcontains $distro) {
            $settings.IntegratedWslDistros += $distro
            Write-Host "Added $distro to WSL Integration." -ForegroundColor Green
            $changed = $true
        }
    }

    if ($changed) {
        # Save the updated settings
        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
        Write-Host "Docker Desktop settings updated successfully." -ForegroundColor Green
        
        # Note: Docker Desktop restart is required for changes to take effect
        Write-Host "Please restart Docker Desktop to apply changes." -ForegroundColor Yellow
        # docker desktop restart
    } else {
        Write-Host "No changes needed. WSL Integration for target distributions is already enabled." -ForegroundColor Gray
    }
} else {
    Write-Warning "Docker Desktop settings file not found at $settingsPath. Is Docker Desktop installed?"
}
