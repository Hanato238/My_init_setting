<#
.SYNOPSIS
  notebooklm-mcp-cli の `nlm login` をDevContainerから実行するために、
  ホスト(Windows)側でChromeを専用プロファイル・リモートデバッグ
  モードで起動します(トラブルシュート用の手動起動)。

.DESCRIPTION
  通常は nlm-login.ps1 (ワンコマンド版) の利用を推奨します。
  このスクリプトは Chrome の起動だけを単独で行いたい場合に使います。

  DevContainer(Linuxコンテナ)にはGUIブラウザが無いため、Googleへの
  対話的ログインができません。このスクリプトは普段使いのChrome
  プロファイルとは完全に分離された専用プロファイルでChromeを起動し、
  CDP(Chrome DevTools Protocol)をポート開放します。
  コンテナ側はこのCDPへ接続してログイン画面を操作します。

  普段使いのCookie・履歴・拡張機能には一切触れません。
  ログイン状態は %LOCALAPPDATA%\nlm-chrome-profile-<コンテナ名> に保存され、
  nlm-login.ps1 と共有されるため、一度ログインすれば次回以降の
  再ログインは(トークンが有効な間)不要です。

.EXAMPLE
  .\host-chrome-debug.ps1

.EXAMPLE
  .\host-chrome-debug.ps1 -Port 9333
#>
param(
    [int]$Port = 9222,
    [string]$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe",
    [string]$ContainerName
)

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

$profileDir = Join-Path $env:LOCALAPPDATA "nlm-chrome-profile-$ContainerName"
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*user-data-dir=$profileDir*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Write-Host "専用プロファイルで Chrome を起動します (port=$Port)"
Write-Host "  プロファイル: $profileDir"
Write-Host ""
Write-Host "このウィンドウでGoogleにログインしたら、コンテナ側のターミナルで次を実行してください:"
Write-Host "  .devcontainer/nlm-login.sh"
Write-Host ""
Write-Host "ログイン状態はプロファイルに保存されるため、Chromeウィンドウを閉じても消えません。"

$proc = Start-Process -FilePath $ChromePath -ArgumentList @(
    "--remote-debugging-port=$Port",
    "--user-data-dir=$profileDir",
    "--no-first-run",
    "--no-default-browser-check"
) -PassThru

Wait-Process -Id $proc.Id

Write-Host "Chrome を終了しました(ログイン状態はプロファイルに保存済み)。"
