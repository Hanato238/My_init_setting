# get workspacepath and if not exist, create it
$workspacePath = "C:\Users\lesen\workspace"
if (-Not (Test-Path -Path $workspacePath)) {
    New-Item -Path $workspacePath -ItemType Directory -Force
}

# Set the workspace path in PowerShell profile
$lineToAdd = '$workspace = "C:\Users\lesen\workspace"'
$profilePath = $PROFILE
if (-not (Get-Content $profilePath | Select-String -Pattern [regex]::Escape($lineToAdd))) {
    Add-Content -Path $profilePath -Value "`n$lineToAdd"
}