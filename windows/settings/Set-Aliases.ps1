# 1. Temporarily bypass execution policy for the current process
Set-ExecutionPolicy Bypass -Scope Process -Force

# 2. Check for administrative privileges and auto-elevate if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrative privileges required. Elevating..." -ForegroundColor Yellow
    # Request elevation while maintaining the bypass policy
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Running with administrative privileges..." -ForegroundColor Green

# Get $PROFILE path
$profilePath = $PROFILE

# Create profile file if it doesn't exist
if (-not (Test-Path -Path $profilePath -PathType Leaf)) {
    New-Item -Path $profilePath -ItemType File -Force
}

# Save backup
if (Test-Path $profilePath) {
    Copy-Item -Path $profilePath -Destination "$profilePath.bak" -Force
}

# Overwrite profile with new content
Set-Content -Path $profilePath -Value @"
function su { Start-Process powershell -Verb runas }
Set-Alias -Name "chrome" -Value "C:\Program Files\Google\Chrome\Application\chrome.exe"
Set-Alias -Name "line" -Value "$env:USERPROFILE\AppData\Local\LINE\bin\LineLauncher.exe"
Set-Alias -Name "zoom" -Value "C:\Program Files\Zoom\bin\Zoom.exe"
Set-Alias -Name "vscode" -Value "C:\Program Files\Microsoft VS Code\Code.exe"
Set-Alias -Name "vpn" -Value "C:\Program Files (x86)\ExpressVPN\expressvpn-ui\ExpressVPN.exe"
Set-Alias -Name "kindle" -Value "C:\Program Files (x86)\Amazon\Kindle\Kindle.exe"
Set-Alias -Name "docker-desktop" -Value "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Set-Alias -Name "git-bash" -Value "C:\Program Files\Git\git-bash.exe"
Set-Alias -Name "powertoys" -Value "C:\Program Files\PowerToys\PowerToys.exe"
Set-Alias -Name "bitwarden" -Value "C:\Users\lesen\AppData\Local\Programs\Bitwarden\Bitwarden.exe"
Set-Alias -Name "spacedesk" -Value "C:\Program Files\datronicsoft\spacedesk\spacedeskConsole.exe"
Set-Alias -Name "gemini" -Value "C:\Users\lesen\AppData\Roaming\npm\gemini.ps1"
Set-Alias -Name "claude" -Value "C:\Users\lesen\AppData\Roaming\npm\claude.ps1"

Set-Alias -Name "powerpoint" -Value "C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE"
Set-Alias -Name "word" -Value "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
Set-Alias -Name "excel" -Value "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"
Set-Alias -Name "onenote" -Value "C:\Program Files\Microsoft Office\root\Office16\ONENOTE.EXE"
Set-Alias -Name "outlook" -Value "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"

function chatgpt { & chrome 'https://chat.openai.com/' }
function gemini-chrome { & chrome 'https://gemini.google.com/app?utm_source=app_launcher&utm_medium=owned&utm_campaign=base_all' }
function claude-chrome { & chrome 'https://claude.ai/' }
function pplx-chrome { & chrome 'https://www.perplexity.ai/' }
function nlm-chrome { & chrome 'https://notebooklm.google.com/' }
function hf-chrome { & chrome 'https://huggingface.co/' }
function context7 { & 'https://context7.com/dashboard' }
function github { & chrome 'https://github.com/' }
function repository { & chrome 'https://community.chocolatey.org/packages' }
function gdrive { & chrome 'https://drive.google.com/drive/' }
function gmail { & chrome 'https://mail.google.com/mail/u/0/?tab=rm&ogbl#inbox' }
function gcp { & chrome 'https://console.cloud.google.com/welcome?hl=ja' }
function gai { & chrome 'https://aistudio.google.com/app/prompts/new_chat' }
function linedev { & chrome 'https://developers.line.biz/console/' }
function lineoam { & chrome 'https://manager.line.biz/' }
function openai { & chrome 'https://platform.openai.com/settings/organization/general' }
function phantomjs { & chrome 'https://dashboard.phantomjscloud.com/dash.html' }
function tencentc { & chrome 'https://www.tencentcloud.com/' }
function rainio { & chrome 'https://app.raindrop.io/my/0' }
function youtube { & chrome 'https://www.youtube.com/' }
function qq { & chrome 'https://www.e-igakukai.jp/user_service/kaiin_portal/home/home.htm' }
function mf { & chrome 'https://moneyforward.com/' }
function oe { & chrome 'https://www.openevidence.com/' }
function keepa { & chrome 'https://keepa.com/#!' }
function asc { & chrome 'https://sellercentral.amazon.co.jp/home' }

Set-Alias -Name "vectra" -Value "C:\Vectra\bin\vectra.exe"
Set-Alias -Name "dbManager" -Value "C:\Program Files\Canfield Scientific Inc\DbManager\bin\dbmanager.exe"
function vectraDb { & explorer "C:\ProgramData\Canfield\Databases\HairMetrixDB"}
"@

# Inject secret store to environment variables in $PROFILE
Add-Content -Path $profilePath -Value @'

# Inject all secrets from SecretStore to Environment Variables dynamically
function Load-SecretEnvironment {
    if (Get-Module -ListAvailable Microsoft.PowerShell.SecretStore) {
        Get-SecretInfo -Vault LocalStore -ErrorAction SilentlyContinue | ForEach-Object {
            $name = $_.Name
            $val = Get-Secret -Name $name -AsPlainText -ErrorAction SilentlyContinue
            if ($val) {
                Set-Content -Path "Env:\$name" -Value $val
            }
        }
    }
}

# Run once on startup
Load-SecretEnvironment

# Command to quickly sync Bitwarden updates to the local environment
function Sync-ApiKeys {
    Write-Host "Fetching latest keys from Bitwarden..." -ForegroundColor Cyan
    $scriptPath = "$HOME\workspace\My_init_setting\windows\installer\Initialize-Security.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath
        Write-Host "Applying keys to the current session..." -ForegroundColor Cyan
        Load-SecretEnvironment
        Write-Host "API keys synchronized successfully." -ForegroundColor Green
    } else {
        Write-Host "Error: Could not find $scriptPath" -ForegroundColor Red
    }
}
'@

# Configure SecretStore
Set-SecretStoreConfiguration -Authentication None -Interaction None -Confirm:$false
# Set the startup directory
$setLocationLine = 'Set-Location "C:\Users\lesen\workspace"'

Write-Host "PowerShell profile has been overwritten with new aliases." -ForegroundColor Green
Write-Host "Please restart PowerShell to apply the changes." -ForegroundColor Yellow
