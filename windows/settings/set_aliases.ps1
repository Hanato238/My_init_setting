Set-ExecutionPolicy Bypass -Scope Process -Force

# Set $PROFILE
$profilePath = $PROFILE
if (-not (Test-Path -Path $profilePath -PathType Leaf)) {
    New-Item -Path $profilePath -ItemType File
}
# get $PROFILE content other than that starts with "Set-Alias"
$lines = Get-Content $profilePath
$filteredLines = $lines | Where-Object { -not ($_ -match '^\s*Set-Alias') }

# backup $PROFILE
Copy-Item -Path $PROFILE -Destination "$PROFILE.bak"

# set $PROFILE content
Set-Content -Path $profilePath -Value $filteredLines

# set new Aliases
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