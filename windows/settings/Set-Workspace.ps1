Set-ExecutionPolicy Bypass -Scope Process -Force

$workspacePath = Join-Path -Path $HOME -ChildPath "workspace"

if (-not (Test-Path -Path $workspacePath)) {
    New-Item -Path $workspacePath -ItemType Directory -Force | Out-Null
    Write-Host "Workspace directory created at $workspacePath" -ForegroundColor Green
} else {
    Write-Host "Workspace directory already exists at $workspacePath" -ForegroundColor Yellow
}
