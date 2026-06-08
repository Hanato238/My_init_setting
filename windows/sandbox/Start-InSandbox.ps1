Set-ExecutionPolicy Bypass -Scope LocalMachine -Force
Set-Location C:\setup\windows

# ============================================================
# デバッグしたいスクリプトのコメントを外して実行する
# ============================================================

# --- フルセットアップ（DryRun） ---
# . .\Start-Setup.ps1 -DryRun

# --- フルセットアップ（Office なし、実際に実行） ---
# . .\Start-Setup.ps1

# --- フルセットアップ（Office 含む） ---
# . .\Start-Setup.ps1 -IncludeOffice

# --- 更新モード（DryRun） ---
# . .\Start-Setup.ps1 -Update -DryRun

# --- 更新モード（実際に実行） ---
# . .\Start-Setup.ps1 -Update

# --- Bitwarden 同期のみ ---
# . .\Start-Setup.ps1 -SyncSecrets

# --- 個別スクリプト（DryRun） ---
# . .\installer\Install-Apps.ps1 -DryRun
# . .\installer\Install-Apps.ps1 -Update -DryRun
# . .\installer\Install-Office.ps1 -DryRun
# . .\installer\Setup-Wsl.ps1 -DryRun
# . .\installer\Setup-Wsl.ps1 -Update -DryRun
# . .\settings\Set-Aliases.ps1
# . .\settings\Set-McpServers.ps1 -DryRun
# . .\settings\Set-WindowsSettings.ps1 -DryRun

# --- Pester テスト ---
# Install-Module Pester -Force -SkipPublisherCheck
# Invoke-Pester C:\setup\windows\tests\ -Output Detailed

# ============================================================
# デフォルト：DryRun でインストール内容を表示
# ============================================================
Write-Host "=== Sandbox デバッグ環境 ===" -ForegroundColor Green
Write-Host "リポジトリ: C:\setup\windows" -ForegroundColor Cyan
Write-Host ""
Write-Host "主なデバッグコマンド:" -ForegroundColor Yellow
Write-Host "  . .\Start-Setup.ps1 -DryRun              # 初回セットアップ内容の確認"
Write-Host "  . .\Start-Setup.ps1 -Update -DryRun      # 更新内容の確認"
Write-Host "  . .\Start-Setup.ps1                      # 実際に初回セットアップを実行"
Write-Host "  . .\Start-Setup.ps1 -Update              # 実際に更新を実行"
Write-Host ""
Write-Host "DryRun モードでインストール内容を確認中..." -ForegroundColor Cyan
. .\Start-Setup.ps1 -DryRun
