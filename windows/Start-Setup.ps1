# Run PowerShell as Administrator before executing this script

Set-ExecutionPolicy Bypass -Scope Process -Force

# iex (iwr ...) で実行された場合 $PSScriptRoot が空になるため、
# リポジトリ全体をダウンロードしてローカルから再実行する
if (-not $PSScriptRoot) {
    $tempDir = Join-Path $env:TEMP "My_init_setting"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }

    Write-Host "Downloading repository..." -ForegroundColor Yellow
    $zipPath = "$tempDir.zip"
    Invoke-WebRequest -Uri "https://github.com/Hanato238/My_init_setting/archive/refs/heads/main.zip" `
        -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force
    Remove-Item $zipPath
    Rename-Item "$env:TEMP\My_init_setting-main" $tempDir

    Write-Host "Restarting from local copy..." -ForegroundColor Yellow
    & "$tempDir\windows\Start-Setup.ps1"
} else {
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
}
