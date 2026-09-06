<#
.SYNOPSIS
  ホストの環境変数登録と、bws-login によるコンテナへの環境変数の受け渡しを検証する。

.DESCRIPTION
  1. secrets.list の有効な (コメントアウトされていない) 名前を列挙
  2. ホスト環境変数 (Process / User / Machine) にそれらが設定されているか点検
  3. コンテナが起動していれば bws-login.ps1 を実行し、コンテナ内で
     verify-in-container.sh を走らせて ~/.secrets と各名前の解決状況を表示

.PARAMETER HostOnly
  ホスト側の点検だけ行い、コンテナには触れない。

.PARAMETER SkipLogin
  bws-login.ps1 を実行せず、現在のコンテナ状態だけを点検する。

.PARAMETER SimulateHostVar
  docker exec -e で VERIFY_HOST_VAR を注入して load-secrets.sh を再実行し、
  「ホスト env があれば bws より優先し ~/.secrets には書かない」ロジックを確認する。
  secrets.list に VERIFY_HOST_VAR を追記しておくこと。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File verify\Verify-BwsFlow.ps1 -HostOnly

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File verify\Verify-BwsFlow.ps1
#>
param(
    [string]$ContainerName = 'claude_container_template',
    [string]$ListFile,
    [string]$Token,
    [switch]$HostOnly,
    [switch]$SkipLogin,
    [switch]$SimulateHostVar
)

$ErrorActionPreference = 'Stop'

if (-not $ListFile)  { $ListFile  = Join-Path $PSScriptRoot '..\.devcontainer\secrets.list' }
$loginScript = Join-Path $PSScriptRoot '..\.devcontainer\bws-login.ps1'

function Format-Mask {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return '-' }
    if ($Value.Length -le 6) { return '******' }
    '{0}...{1} (len={2})' -f $Value.Substring(0, 3), $Value.Substring($Value.Length - 3), $Value.Length
}

if (-not (Test-Path -LiteralPath $ListFile)) {
    Write-Error "secrets.list が見つかりません: $ListFile"
    return
}

# 1. 有効な名前
$names = @(
    Get-Content -LiteralPath $ListFile |
        ForEach-Object { ($_ -replace '#.*', '').Trim() } |
        Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*$' }
)
Write-Host "secrets.list: $ListFile" -ForegroundColor Cyan
Write-Host "有効な名前: $($names.Count)" -ForegroundColor Cyan
if ($names.Count -eq 0) {
    Write-Warning "すべてコメントアウトされています。行頭の '#' を外してから再実行してください。"
    if (-not $SimulateHostVar) { return }
}

# 2. ホスト環境変数
Write-Host "`n=== ホスト環境変数 ===" -ForegroundColor Cyan
$hostSet = 0
foreach ($n in $names) {
    $v = $null
    foreach ($scope in 'Process', 'User', 'Machine') {
        $v = [Environment]::GetEnvironmentVariable($n, $scope)
        if ($v) { break }
    }
    if ($v) {
        $hostSet++
        '{0,-26} SET    {1}  [{2}]' -f $n, (Format-Mask $v), $scope
    }
    else {
        '{0,-26} ----' -f $n
    }
}
Write-Host "ホストで設定済み: $hostSet / $($names.Count)"

if ($HostOnly) { return }

# 3. コンテナ状態
$state = docker inspect --format '{{.State.Status}}' $ContainerName 2>$null
if ($state -ne 'running') {
    Write-Error "コンテナ '$ContainerName' が起動していません (state: '$state')。'claude' で起動してください。"
    return
}

# 4. bws-login
if (-not $SkipLogin) {
    Write-Host "`n=== bws-login.ps1 実行 ===" -ForegroundColor Cyan
    if ($Token) { & $loginScript -ContainerName $ContainerName -Token $Token }
    else        { & $loginScript -ContainerName $ContainerName }
    if ($LASTEXITCODE) { Write-Warning "bws-login.ps1 が非ゼロ終了しました ($LASTEXITCODE)" }
}

# 5. コンテナ内点検
Write-Host "`n=== コンテナ内の状態 ===" -ForegroundColor Cyan
$inspect = 'bash /workspace/verify/verify-in-container.sh'

if ($SimulateHostVar) {
    Write-Host "(VERIFY_HOST_VAR を注入して load-secrets.sh を再実行します)" -ForegroundColor DarkGray
    $reload = 'BWS_ACCESS_TOKEN="$(cat ~/.config/bws/access-token 2>/dev/null)" bash /workspace/.devcontainer/load-secrets.sh; echo'
    docker exec -e VERIFY_HOST_VAR=hello-from-host-sim $ContainerName bash -lc "$reload; $inspect"
}
else {
    docker exec $ContainerName bash -lc $inspect
}

Write-Host "`n完了。SOURCE の見方:" -ForegroundColor Green
Write-Host "  bws->file : bws から取得し ~/.secrets に書かれた"
Write-Host "  host/env  : compose environment: / 注入で供給 (~/.secrets には書かれない = ホスト優先)"
Write-Host "  MISSING   : bws にも env にも無い (skip された)"
