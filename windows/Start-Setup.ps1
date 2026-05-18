# Run PowerShell as Administrator before executing this script

Set-ExecutionPolicy Bypass -Scope Process -Force

# installer スクリプトを順番に実行（依存関係があるため順序固定）
# 新しいスクリプトを追加する場合はこのリストに追記する
$installerOrder = @(
    "Install-Chocolatey.ps1",
    "Install-Apps.ps1",
    "Install-Office.ps1",
    "Install-Wsl.ps1",
    "Initialize-Security.ps1",
    "Install-LlmCli.ps1"
)

foreach ($script in $installerOrder) {
    $path = "$PSScriptRoot\installer\$script"
    if (Test-Path $path) {
        Write-Host "`n=== Running installer: $script ===" -ForegroundColor Cyan
        & $path
    } else {
        Write-Warning "Script not found, skipping: $path"
    }
}

# settings スクリプトをすべて自動検出して実行
Get-ChildItem "$PSScriptRoot\settings\*.ps1" | Sort-Object Name | ForEach-Object {
    Write-Host "`n=== Running settings: $($_.Name) ===" -ForegroundColor Cyan
    & $_.FullName
}
