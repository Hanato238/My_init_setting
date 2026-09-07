<#
.SYNOPSIS
  Bitwarden Secrets Manager CLI (bws) のアクセストークンを DevContainer 内へ保存します。

.DESCRIPTION
  bws はブラウザ OAuth を伴わず、マシンアカウントのアクセストークン文字列だけで動きます。
  そのため gws-login / nlm-login のような「ホストで対話認証 → 結果を引き渡し」ではなく、
  すでに手元にあるトークンをコンテナ内の ~/.config/bws/access-token へ書き込むだけです。

  トークンの取得元は次の優先順位:
    1. -Token 引数
    2. 環境変数 BWS_ACCESS_TOKEN
    3. ホスト側ファイル %USERPROFILE%\.config\bws\access-token
    4. 対話入力 (エコーなし)

  書き込み後、コンテナ内で `bws project list` を実行して疎通確認し、続けて
  .devcontainer/load-secrets.sh を実行して secrets.list の許可リストにある変数を
  ~/.secrets へ取り込みます (ホスト env 優先、無ければ bws)。
  以後コンテナ内のログインシェルは /etc/profile.d/bws.sh 経由で BWS_ACCESS_TOKEN を
  自動 export します。トークンはコンテナを作り直すまで有効です
  (作り直したら再実行してください)。

  セキュリティ: このトークンは対象プロジェクトの全シークレット読み取り権を持ちます。
  自動 export のため、コンテナ内シェルから起動した Claude Code / MCP サーバーも
  トークンを環境変数として参照できます (利便性優先の設計)。dev コンテナ限定で使い、
  コミット・共有はしないこと。漏洩時は Bitwarden 側でトークンをローテートします。
  -Token 引数はホストのコマンド履歴に残るため、環境変数かプロンプト入力を推奨します。

  コンテナ名はこのスクリプトの親ディレクトリ名から自動判定します
  (docker-compose.yml の container_name と同じ規則)。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .devcontainer\bws-login.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .devcontainer\bws-login.ps1 -Token "0.xxxxxxxx..."
#>
param(
    [string]$Token,
    [string]$ContainerName
)

$ErrorActionPreference = "Stop"

if (-not $ContainerName) {
    $ContainerName = (Get-Item (Split-Path -Parent $PSScriptRoot)).Name
}

$running = docker ps --filter "name=^/${ContainerName}$" --format "{{.Names}}" 2>$null
if (-not $running) {
    Write-Error "コンテナ '$ContainerName' が起動していません。先に DevContainer を起動してください。"
    exit 1
}

if (-not $Token) { $Token = $env:BWS_ACCESS_TOKEN }
if (-not $Token) {
    $hostTokenFile = Join-Path $env:USERPROFILE ".config\bws\access-token"
    if (Test-Path $hostTokenFile) {
        $Token = (Get-Content -Raw -Path $hostTokenFile).Trim()
        Write-Host "ホスト側 $hostTokenFile からトークンを読み込みました。"
    }
}
if (-not $Token) {
    $secure = Read-Host -AsSecureString "bws access token"
    $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}
$Token = $Token.Trim()
if (-not $Token) {
    Write-Error "アクセストークンが空です。"
    exit 1
}
$colon = if ($Token.Contains(':')) { 'コロンあり' } else { 'コロンなし = 切れています' }
Write-Host ("トークン: {0} 文字 ({1})" -f $Token.Length, $colon)

$credDir  = "/home/node/.config/bws"
$credPath = "$credDir/access-token"

# gws-login.ps1 と同じ理由: パイプ経由だとプロファイルのエンコーディング設定で BOM が
# 混入するため、BOM 無し UTF-8 の一時ファイルを docker cp で送り込む。
docker exec -u root $ContainerName bash -lc "mkdir -p $credDir"
if ($LASTEXITCODE -ne 0) { Write-Error "コンテナ側ディレクトリの作成に失敗しました。"; exit $LASTEXITCODE }

$tmpFile = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($tmpFile, $Token, (New-Object System.Text.UTF8Encoding($false)))
    docker cp $tmpFile "${ContainerName}:$credPath"
    if ($LASTEXITCODE -ne 0) { Write-Error "コンテナへのトークンのコピーに失敗しました。"; exit $LASTEXITCODE }
} finally {
    # %TEMP% は本人 ACL のみだが、削除前に上書きして平文トークンをディスクに残さない。
    if (Test-Path $tmpFile) {
        [System.IO.File]::WriteAllText($tmpFile, ('0' * 512))
        Remove-Item -Path $tmpFile -ErrorAction SilentlyContinue
    }
}

docker exec -u root $ContainerName bash -lc "chown node:node $credDir $credPath && chmod 600 $credPath"
if ($LASTEXITCODE -ne 0) { Write-Error "コンテナ側の権限設定に失敗しました。"; exit $LASTEXITCODE }

Write-Host "コンテナ内で疎通確認します..."
# ログインシェルが /etc/profile.d/bws.sh 経由で BWS_ACCESS_TOKEN を自動 export するので、
# ここでインライン指定はしない（PowerShell 5.1 が docker.exe への引数中の " を壊すため）。
docker exec $ContainerName bash -lc 'bws project list -o table'
if ($LASTEXITCODE -ne 0) {
    Write-Warning "bws project list に失敗しました。トークンを確認してください。"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "secrets.list を読み込みます..."
docker exec $ContainerName bash -lc 'bash /workspace/.devcontainer/load-secrets.sh'
if ($LASTEXITCODE -ne 0) {
    Write-Warning "load-secrets.sh が失敗しました（後でコンテナ内から手動実行できます）。"
}

Write-Host ""
Write-Host "完了しました。新しいシェル (zellij ペイン等) から bws が使えます。"
