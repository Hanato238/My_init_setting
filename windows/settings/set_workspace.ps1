Set-ExecutionPolicy Bypass -Scope Process -Force

# get workspacepath and if not exist, create it
$workspacePath = "C:\Users\lesen\workspace"
if (-Not (Test-Path -Path $workspacePath)) {
    New-Item -Path $workspacePath -ItemType Directory -Force
    Write-Host "Workspace directory created at $workspacePath" -ForegroundColor Green
}

# Set the workspace path in PowerShell profile
$lineToAdd = '$workspace = "C:\Users\lesen\workspace"'
$profilePath = $PROFILE

if (Test-Path $profilePath) {
    if (-not (Get-Content $profilePath | Select-String -Pattern ([regex]::Escape($lineToAdd)))) {
        Add-Content -Path $profilePath -Value "`n$lineToAdd"
        Write-Host "Workspace path added to PowerShell profile." -ForegroundColor Green
    }
    else{
        Write-Host "Workspace path already exists in PowerShell profile." -ForegroundColor Yellow
    }
} else {
    Set-Content -Path $profilePath -Value $lineToAdd
    Write-Host "PowerShell profile created and workspace path added." -ForegroundColor Green
}