# GitHubのリリースURLベース（末尾にスラッシュ）
$baseUrl = "https://github.com/hanato238/My_init_setting/windows"
$targetDir = "C:\windows\user\lesen\downloads\setup_files"

# ダウンロードしたいファイル一覧
$fileList = @(
    "setup.exe",
    "configuration-Office2021Enterprise.xml",
    "run-after.ps1"
)

# 保存先フォルダがなければ作成
if (-not (Test-Path $targetDir)) {
    New-Item -Path $targetDir -ItemType Directory -Force
}

# 各ファイルをGitHubからダウンロード
foreach ($file in $fileList) {
    $url = "$baseUrl$file"
    $dest = Join-Path $targetDir $file
    Invoke-WebRequest -Uri $url -OutFile $dest
}

# 実行1：setup.exe + 構成ファイル
Start-Process -FilePath "$targetDir\setup.exe" -ArgumentList "/configure $targetDir\configuration-Office2021Enterprise.xml" -Wait

# 実行2：後続のPowerShellスクリプト
powershell -ExecutionPolicy Bypass -File "$targetDir\run-after.ps1"
