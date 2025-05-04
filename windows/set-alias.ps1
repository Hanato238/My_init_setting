# Set $PROFILE
$profilePath = $PROFILE
if (-not (Test-Path -Path $profilePath -PathType Leaf)) {
    New-Item -Path $profilePath -ItemType File
}
# プロファイル内容を読み込む（行単位）
$lines = Get-Content $profilePath

# Set-Alias で始まる行を除外
$filteredLines = $lines | Where-Object { -not ($_ -match '^\s*Set-Alias') }

# 元のPROFILEをバックアップ
Copy-Item -Path $PROFILE -Destination "$PROFILE.bak"

# 上書き保存（元のファイルを更新）
Set-Content -Path $profilePath -Value $filteredLines

# Set-Alias
Add-Content -Path $profilePath -Value @"
function su { Start-Process powershell -Verb runas }
Set-Alias -Name "chrome" -Value "C:\Program Files\Google\Chrome\Application\chrome.exe"
Set-Alias -Name "chatgpt" -Value "C:\Program Files\Google\Chrome\Application\chrome.exe https://chat.openai.com/"
Set-Alias -Name "line" -Value "C:\Users\lesen\AppData\Local\LINE\bin\LineLauncher.exe"
Set-Alias -Name "vscode" -Value "C:\Program Files\Microsoft VS Code\Code.exe"
Set-Alias -Name "expressvpn" -Value "C:\Program Files (x86)\ExpressVPN\expressvpn-ui\ExpressVPN.exe"
Set-Alias -Name "kindle" -Value "C:\Program Files (x86)\Amazon\Kindle\Kindle.exe"
Set-Alias -Name "docker-desktop" -Value "C:\Program Files\Docker\Docker\Docker Desktop.exe"
"@