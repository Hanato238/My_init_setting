<#
.SYNOPSIS
  notebooklm-mcp-cli の `nlm login` をワンコマンドで実行します。

.DESCRIPTION
  1. 専用の永続プロファイルでホスト側 Chrome を CDP モード起動
  2. DevContainer 内で nlm-login.sh (CDPプロキシ + nlm login) を自動実行
  3. 終了後、Chrome プロセスのみ片付け(プロファイルは次回のため残す)

  普段使いの Chrome プロファイル(Cookie・履歴・拡張機能)には一切触れません。
  ログイン状態は %LOCALAPPDATA%\nlm-chrome-profile-<コンテナ名> に保存され、
  次回以降はこのプロファイルの Cookie がそのまま使われるため、トークンが
  有効な間は再ログイン操作は不要です。
  コンテナ名はこのスクリプトの親ディレクトリ名から自動判定します
  (docker-compose.yml の container_name と同じ規則)。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .devcontainer\nlm-login.ps1

.EXAMPLE
  .devcontainer\nlm-login.cmd
#>
param(
    [int]$Port = 9222,
    [string]$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe",
    [string]$ContainerName
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ChromePath)) {
    $ChromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}
if (-not (Test-Path $ChromePath)) {
    Write-Error "Chrome が見つかりません。-ChromePath で実行ファイルのパスを指定してください。"
    exit 1
}

if (-not $ContainerName) {
    $ContainerName = (Get-Item (Split-Path -Parent $PSScriptRoot)).Name
}

$running = docker ps --filter "name=^/${ContainerName}$" --format "{{.Names}}" 2>$null
if (-not $running) {
    Write-Error "コンテナ '$ContainerName' が起動していません。先に DevContainer を起動してください。"
    exit 1
}

$profileDir = Join-Path $env:LOCALAPPDATA "nlm-chrome-profile-$ContainerName"
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

# 前回異常終了時の残存プロセスがあれば片付ける(同一プロファイルの多重起動を防ぐ)
Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*user-data-dir=$profileDir*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Write-Host "専用プロファイルで Chrome を起動します (port=$Port)"
Write-Host "  プロファイル: $profileDir"

$chromeProc = Start-Process -FilePath $ChromePath -ArgumentList @(
    "--remote-debugging-port=$Port",
    "--user-data-dir=$profileDir",
    "--no-first-run",
    "--no-default-browser-check"
) -PassThru

function Cleanup {
    Write-Host ""
    Write-Host "後片付け中..."
    Stop-Process -Id $chromeProc.Id -Force -ErrorAction SilentlyContinue
    Write-Host "Chrome を終了しました(ログイン状態はプロファイルに保存済み)。"
}

$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -UseBasicParsing -TimeoutSec 2 | Out-Null
        $ready = $true
        break
    } catch {}
}
if (-not $ready) {
    Write-Error "Chrome の CDP (port $Port) に接続できませんでした。"
    Cleanup
    exit 1
}

Write-Host "コンテナ '$ContainerName' 側で nlm login を実行します..."
Write-Host "開いた Chrome ウィンドウで Google にログインしてください。"
Write-Host ""

$ttyFlag = if ([Console]::IsInputRedirected) { "-i" } else { "-it" }
docker exec $ttyFlag -e "NLM_CDP_TARGET_PORT=$Port" -e "NLM_CDP_LISTEN_PORT=$Port" $ContainerName bash -lc "cd /workspace && .devcontainer/nlm-login.sh"
$loginExitCode = $LASTEXITCODE

Cleanup

if ($loginExitCode -ne 0) {
    Write-Warning "nlm login はエラー終了しました (exit code $loginExitCode)。"
    exit $loginExitCode
}

Write-Host "完了しました。"
