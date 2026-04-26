Set-ExecutionPolicy Bypass -Scope Process -Force

# $PROFILE のパスを取得
$profilePath = $PROFILE

# プロファイルファイルが存在しない場合は作成
if (-not (Test-Path -Path $profilePath -PathType Leaf)) {
    New-Item -Path $profilePath -ItemType File -Force
}

# バックアップを保存
if (Test-Path $profilePath) {
    Copy-Item -Path $profilePath -Destination "$profilePath.bak" -Force
}

# 新しい内容で完全上書き
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

Set-Alias -Name "powerpoint" -Value "C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE"
Set-Alias -Name "word" -Value "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
Set-Alias -Name "excel" -Value "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"
Set-Alias -Name "onenote" -Value "C:\Program Files\Microsoft Office\root\Office16\ONENOTE.EXE"
Set-Alias -Name "outlook" -Value "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"
Set-Alias -Name "gemini" -Value "C:\ProgramData\chocolatey\bin\gemini.exe"
Set-Alias -Name "claude" -Value "C:\ProgramData\chocolatey\bin\claude.exe"

function chatgpt { & chrome 'https://chat.openai.com/' }
function gemini-chrome { & chrome 'https://gemini.google.com/app?utm_source=app_launcher&utm_medium=owned&utm_campaign=base_all' }
function claude-chrome { & chrome 'https://claude.ai/' }
function pplx-chrome { & chrome 'https://www.perplexity.ai/' }
function nlm-chrome { & chrome 'https://notebooklm.google.com/' }
function hf-chrome { & chrome 'https://huggingface.co/' }
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
function rainio { & chrome 'https://app.raindrop.io/my/0' }
function youtube { & chrome 'https://www.youtube.com/' }
function qq { & chrome 'https://www.e-igakukai.jp/user_service/kaiin_portal/home/home.htm' }
function mf { & chrome 'https://moneyforward.com/' }
function oe { & chrome 'https://www.openevidence.com/' }

Set-Alias -Name "vectra" -Value "C:\Vectra\bin\vectra.exe"
Set-Alias -Name "dbManager" -Value "C:\Program Files\Canfield Scientific Inc\DbManager\bin\dbmanager.exe"
function vectraDb { & explorer "C:\ProgramData\Canfield\Databases\HairMetrixDB"}
"@

# SecretStore → 環境変数注入を $PROFILE に追記（シングルクォートで $ を展開しない）
Add-Content -Path $profilePath -Value @'

# MCP サーバ用 API キーを SecretStore から環境変数に注入
function Set-McpEnv($secret, $env) {
    $v = Get-Secret -Name $secret -AsPlainText -ErrorAction SilentlyContinue
    if ($v) { [System.Environment]::SetEnvironmentVariable($env, $v) }
}
Set-McpEnv "PERPLEXITY_API_KEY"           "PERPLEXITY_API_KEY"
Set-McpEnv "GITHUB_PERSONAL_ACCESS_TOKEN" "GITHUB_PERSONAL_ACCESS_TOKEN"
Set-McpEnv "BRIGHTDATA_API_TOKEN"         "API_TOKEN"
Set-McpEnv "HF_TOKEN"                     "HF_TOKEN"
Set-McpEnv "GW_MCP_CLIENT_ID"             "GOOGLE_CLIENT_ID"
Set-McpEnv "GW_MCP_CLIENT_SECRET"         "GOOGLE_CLIENT_SECRET"
'@

Write-Host "PowerShell profile has been overwritten with new aliases." -ForegroundColor Green
Write-Host "Please restart PowerShell to apply the changes." -ForegroundColor Yellow
