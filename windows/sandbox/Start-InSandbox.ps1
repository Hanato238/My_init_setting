Set-ExecutionPolicy Bypass -Scope Process -Force
Set-Location C:\setup\windows

# ============================================================
# デバッグしたいスクリプトのコメントを外して実行する
# ============================================================

# --- フルセットアップ ---
# . .\Start-Setup.ps1

# --- インストールのみ（-DryRun で内容確認） ---
# . .\installer\Install-Apps.ps1 -DryRun

# --- インストールのみ（実際に実行） ---
# . .\installer\Install-Apps.ps1

# --- LLM CLI セットアップのみ ---
# . .\installer\install-llmcli.ps1 -DryRun

# --- エイリアス設定のみ ---
# . .\settings\Set-Aliases.ps1

# --- MCP サーバー設定のみ ---
# . .\settings\Set-McpServers.ps1

# --- Pester テスト（要 Pester インストール） ---
# Install-Module Pester -Force -SkipPublisherCheck
# Invoke-Pester C:\setup\windows\tests\ -Output Detailed

# ============================================================
# デフォルト：DryRun でインストール内容を表示
# ============================================================
Write-Host "=== Sandbox デバッグ環境 ===" -ForegroundColor Green
Write-Host "スクリプトは C:\setup\windows に配置されています。" -ForegroundColor Cyan
Write-Host ""
Write-Host "DryRun モードでインストール内容を確認中..." -ForegroundColor Cyan
. .\installer\Install-Apps.ps1 -DryRun
