<#
.SYNOPSIS
  Google Workspace CLI (gws) の認証をワンコマンドで実行し、DevContainerへ引き渡します。

.DESCRIPTION
  gws auth login はブラウザ OAuth2 フロー完了後、動的に選ばれたローカルポート
  (例: localhost:42389) へのコールバックを待ち受けます。DevContainer 側でこの
  ポートを認証のたびに公開するのは現実的ではないため、nlm-login.ps1 と同じ
  「ホスト側で認証を完結させ、結果だけコンテナへ渡す」方式を採ります。

  1. ホスト側 Windows で `gws auth login` を実行(通常のブラウザ OAuth2 フロー。
     コールバックはホストの localhost 上で完結するため動的ポートでも問題なし)
  2. `gws auth export` で取得した認証情報(refresh_token 等)を DevContainer 内の
     ~/.config/gws/credentials.json へ書き込みます
  3. コンテナ内の gws は以後この資格情報ファイルを使い、ブラウザ認証なしで動作します

  ログイン状態はホスト側 gws の認証ストア(keyring)に保存されるため、
  トークンが有効な間は再ログイン操作は不要です(再実行すればコンテナ側にも
  再度引き渡されます)。
  コンテナ名はこのスクリプトの親ディレクトリ名から自動判定します
  (docker-compose.yml の container_name と同じ規則)。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .devcontainer\gws-login.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .devcontainer\gws-login.ps1 -Force
#>
param(
    [string]$ContainerName,
    [switch]$Force
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

if ($Force) {
    Write-Host "既存の認証情報をクリアします (-Force)..."
    & gws auth logout | Out-Null
}

Write-Host "ホスト側で gws auth login を実行します..."
Write-Host "開いたブラウザで Google にログインしてください。"
Write-Host ""

& gws auth login
if ($LASTEXITCODE -ne 0) {
    Write-Error "gws auth login に失敗しました (exit code $LASTEXITCODE)。"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "コンテナ '$ContainerName' へ認証情報を引き渡します..."

# 先頭の "Using keyring backend: keyring" 等の案内行を除き、JSON部分のみ抽出
$credsJson = (& gws auth export --unmasked | Where-Object { $_ -match '^\s*[\{\}"]' }) -join "`n"
if (-not $credsJson) {
    Write-Error "gws auth export の出力を取得できませんでした。"
    exit 1
}

# DevContainer側の ~/.config/gws は client_secret.json の単一ファイルマウントにより
# ディレクトリ自体が root 所有(0755)で自動生成されるため、node ユーザーからは
# 書き込めない(discoveryキャッシュ等の生成も同様に失敗する)。
# -u root で書き込んだ後、ディレクトリと credentials.json だけ node に所有権を戻す。
# client_secret.json は read-only bind mount のため -R での一括 chown は失敗する。
$credPath = "/home/node/.config/gws/credentials.json"
$credDir  = "/home/node/.config/gws"

# docker exec -i へパイプで渡すと、プロファイルが $OutputEncoding / [Console]::OutputEncoding を
# BOM付きUTF-8に設定している影響で標準入力に BOM が混入し、gws 側の JSON パースが
# 「Bad authorized user secret: expected value at line 1 column 1」で失敗する。
# docker cp でファイルごとコピーする方式にして、パイプのエンコーディング変換を経由しないようにする。
docker exec -u root $ContainerName bash -lc "mkdir -p $credDir"
if ($LASTEXITCODE -ne 0) {
    Write-Error "コンテナ側ディレクトリの作成に失敗しました。"
    exit $LASTEXITCODE
}

$tmpFile = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($tmpFile, $credsJson, (New-Object System.Text.UTF8Encoding($false)))
    docker cp $tmpFile "${ContainerName}:$credPath"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "コンテナへの認証情報のコピーに失敗しました。"
        exit $LASTEXITCODE
    }
} finally {
    Remove-Item -Path $tmpFile -ErrorAction SilentlyContinue
}

docker exec -u root $ContainerName bash -lc "chown node:node $credDir $credPath && chmod 600 $credPath"
if ($LASTEXITCODE -ne 0) {
    Write-Error "コンテナ側の権限設定に失敗しました。"
    exit $LASTEXITCODE
}

Write-Host "コンテナ内の認証状態を確認します..."
docker exec $ContainerName gws auth status

Write-Host ""
Write-Host "完了しました。"
