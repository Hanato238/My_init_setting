Set-ExecutionPolicy Bypass -Scope Process -Force

# Set $PROFILE
$profilePath = $PROFILE
if (-not (Test-Path -Path $profilePath -PathType Leaf)) {
    New-Item -Path $profilePath -ItemType File -Force
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
Set-Alias -Name "line" -Value "C:\Users\lesen\AppData\Local\LINE\bin\LineLauncher.exe"
Set-Alias -Name "vscode" -Value "C:\Program Files\Microsoft VS Code\Code.exe"
Set-Alias -Name "vpn" -Value "C:\Program Files (x86)\ExpressVPN\expressvpn-ui\ExpressVPN.exe"
Set-Alias -Name "kindle" -Value "C:\Program Files (x86)\Amazon\Kindle\Kindle.exe"
Set-Alias -Name "docker-desktop" -Value "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Set-Alias -Name "git-bash" -Value "C:\Program Files\Git\git-bash.exe"
Set-Alias -Name "powertoys" -Value "C:\Program Files\PowerToys\PowerToys.exe"

Set-Alias -Name "powerpoint" -Value "C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE"
Set-Alias -Name "word" -Value "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
Set-Alias -Name "excel" -Value "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"
Set-Alias -Name "onenote" -Value "C:\Program Files\Microsoft Office\root\Office16\ONENOTE.EXE"
Set-Alias -Name "outlook" -Value "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"

function chatgpt { & chrome 'https://chat.openai.com/' }
function gemini { & chrome 'https://gemini.google.com/app?utm_source=app_launcher&utm_medium=owned&utm_campaign=base_all' }
function github { & chrome 'https://github.com/' }
"@

Write-Host "Aliases have been set in PowerShell profile." -ForegroundColor Green
Write-Host "Please restart PowerShell to apply the changes." -ForegroundColor Yellow