# 定義するワークスペースパス
$workspacePath = "C:\Users\lesen\workspace"

# フォルダが存在しなければ作成
if (-Not (Test-Path -Path $workspacePath)) {
    New-Item -Path $workspacePath -ItemType Directory -Force
}

# 追記するコード
$lineToAdd = '$workspace = "C:\Users\lesen\workspace"'

# すでに同じ内容が書かれていないかチェックしてから追記
$profilePath = $PROFILE
if (-not (Get-Content $profilePath | Select-String -Pattern [regex]::Escape($lineToAdd))) {
    Add-Content -Path $profilePath -Value "`n$lineToAdd"
}
