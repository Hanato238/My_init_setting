# GitHubのベースURL（末尾にスラッシュを忘れずに）
$baseUrl = "https://github.com/hanato238/My_init_setting/app_data"

# ダウンロード対象ファイル
$fileNames = @("setup.exe", "configuration-Office2021Enterprise.xml")

# 保存先フォルダ
$targetDir = "C:\Widnows\Program Files\office"

# フォルダがなければ作成
if (-not (Test-Path -Path $targetDir)) {
    New-Item -Path $targetDir -ItemType Directory -Force
}

# 各ファイルをダウンロード
foreach ($file in $fileNames) {
    $url = "$baseUrl$file"
    $outPath = Join-Path $targetDir $file
    Invoke-WebRequest -Uri $url -OutFile $outPath
}

# フォルダへ移動
Set-Location $targetDir

# setup.exe を構成ファイル付きで実行
Start-Process -FilePath ".\setup.exe" -ArgumentList "/configure .\configuration-Office2021Enterprise.xml" -Wait
