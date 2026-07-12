param([string]$ProfileType = '')

Set-ExecutionPolicy Bypass -Scope Process -Force

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrative privileges required. Elevating..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    return
}

Write-Host "Running with administrative privileges..." -ForegroundColor Green

$profilePath = $PROFILE

if (-not (Test-Path -Path $profilePath -PathType Leaf)) {
    New-Item -Path $profilePath -ItemType File -Force | Out-Null
}

# Rotate backups: keep 3 generations
if (Test-Path "$profilePath.bak.2") { Move-Item "$profilePath.bak.2" "$profilePath.bak.3" -Force }
if (Test-Path "$profilePath.bak") { Move-Item "$profilePath.bak"   "$profilePath.bak.2" -Force }
if (Test-Path $profilePath) { Copy-Item $profilePath "$profilePath.bak" -Force }

$markerStart = "# === MANAGED BY Set-Aliases.ps1 — DO NOT EDIT BETWEEN THESE MARKERS ==="
$markerEnd = "# === END MANAGED SECTION ==="

# Part 1: aliases and URL shortcuts (double-quote heredoc; $ escaped as `$)
$part1 = @"
`$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

`$workspace = "`$env:USERPROFILE\workspace"
Set-Location `$workspace

function su { Start-Process powershell -Verb runas }
Set-Alias -Name "chrome"         -Value "C:\Program Files\Google\Chrome\Application\chrome.exe"
Set-Alias -Name "line"           -Value "`$env:USERPROFILE\AppData\Local\LINE\bin\LineLauncher.exe"
Set-Alias -Name "zoom"           -Value "C:\Program Files\Zoom\bin\Zoom.exe"
Set-Alias -Name "telegram"       -Value "`$env:USERPROFILE\AppData\Roaming\Telegram Desktop\Telegram.exe"
Set-Alias -Name "vpn"            -Value "C:\Program Files (x86)\ExpressVPN\expressvpn-ui\ExpressVPN.exe"
Set-Alias -Name "docker-desktop" -Value "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Set-Alias -Name "git-bash"       -Value "C:\Program Files\Git\git-bash.exe"
Set-Alias -Name "vim"            -Value "C:\Program Files\Vim\vim92\vim.exe"
Set-Alias -Name "ubuntu"         -Value "`$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\ubuntu2404.exe"
Set-Alias -Name "powertoys"      -Value "C:\Program Files\PowerToys\PowerToys.exe"
Set-Alias -Name "bitwarden"      -Value "`$env:USERPROFILE\AppData\Local\Programs\Bitwarden\Bitwarden.exe"
Set-Alias -Name "spacedesk"      -Value "C:\Program Files\datronicsoft\spacedesk\spacedeskConsole.exe"
Set-Alias -Name "gemini"         -Value "`$env:USERPROFILE\AppData\Roaming\npm\gemini.ps1"
Set-Alias -Name "orca"           -Value "`$env:USERPROFILE\AppData\Local\Programs\orca\Orca.exe"

Set-Alias -Name "powerpoint" -Value "C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE"
Set-Alias -Name "word"       -Value "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
Set-Alias -Name "excel"      -Value "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"
Set-Alias -Name "onenote"    -Value "C:\Program Files\Microsoft Office\root\Office16\ONENOTE.EXE"
Set-Alias -Name "outlook"    -Value "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"

function chatgpt      { & chrome 'https://chat.openai.com/' }
function gemini-chrome { & chrome 'https://gemini.google.com/app?utm_source=app_launcher&utm_medium=owned&utm_campaign=base_all' }
function claude-chrome { & chrome 'https://claude.ai/' }
function pplx-chrome  { & chrome 'https://www.perplexity.ai/' }
function nlm-chrome   { & chrome 'https://notebooklm.google.com/' }
function hf-chrome    { & chrome 'https://huggingface.co/' }
function context7     { Start-Process 'https://context7.com/dashboard' }
function github       { & chrome 'https://github.com/' }
function repository   { & chrome 'https://community.chocolatey.org/packages' }
function winstall     { & chrome 'https://winstall.app/' }
function tailnet      { & chrome 'https://login.tailscale.com/admin' }
function gdrive       { & chrome 'https://drive.google.com/drive/' }
function gmail        { & chrome 'https://mail.google.com/mail/u/0/?tab=rm&ogbl#inbox' }
function gcp          { & chrome 'https://console.cloud.google.com/welcome?hl=ja' }
function gai          { & chrome 'https://aistudio.google.com/app/prompts/new_chat' }
function linedev      { & chrome 'https://developers.line.biz/console/' }
function lineoam      { & chrome 'https://manager.line.biz/' }
function openai       { & chrome 'https://platform.openai.com/settings/organization/general' }
function phantomjs    { & chrome 'https://dashboard.phantomjscloud.com/dash.html' }
function tencentc     { & chrome 'https://www.tencentcloud.com/' }
function rainio       { & chrome 'https://app.raindrop.io/my/0' }
function youtube      { & chrome 'https://www.youtube.com/' }
function qq           { & chrome 'https://www.e-igakukai.jp/user_service/kaiin_portal/home/home.htm' }
function mf           { & chrome 'https://moneyforward.com/' }
function oe           { & chrome 'https://www.openevidence.com/' }
function keepa        { & chrome 'https://keepa.com/#!' }
function asc          { & chrome 'https://sellercentral.amazon.co.jp/home' }

Set-Alias -Name "vectra"    -Value "C:\Vectra\bin\vectra.exe"
Set-Alias -Name "dbManager" -Value "C:\Program Files\Canfield Scientific Inc\DbManager\bin\dbmanager.exe"
function vectraDb { & explorer "C:\ProgramData\Canfield\Databases\HairMetrixDB" }
"@

$part1Clinic = @"
`$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

`$workspace = "`$env:USERPROFILE\workspace"
Set-Location `$workspace

function su { Start-Process powershell -Verb runas }
Set-Alias -Name "chrome"    -Value "C:\Program Files\Google\Chrome\Application\chrome.exe"
Set-Alias -Name "vscode"    -Value "`$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code\Code.exe"
Set-Alias -Name "vpn"       -Value "C:\Program Files (x86)\ExpressVPN\expressvpn-ui\ExpressVPN.exe"
Set-Alias -Name "git-bash"  -Value "C:\Program Files\Git\git-bash.exe"
Set-Alias -Name "vim"       -Value "C:\Program Files\Vim\vim92\vim.exe"
Set-Alias -Name "powertoys" -Value "C:\Program Files\PowerToys\PowerToys.exe"
Set-Alias -Name "vectra"    -Value "C:\Vectra\bin\vectra.exe"
Set-Alias -Name "dbManager" -Value "C:\Program Files\Canfield Scientific Inc\DbManager\bin\dbmanager.exe"

function vectraDb { & explorer "C:\ProgramData\Canfield\Databases\HairMetrixDB" }
function gdrive   { & chrome 'https://drive.google.com/drive/' }
function gmail    { & chrome 'https://mail.google.com/mail/u/0/?tab=rm&ogbl#inbox' }
function qq       { & chrome 'https://www.e-igakukai.jp/user_service/kaiin_portal/home/home.htm' }
function oe       { & chrome 'https://www.openevidence.com/' }
"@

# Part 2: function definitions (single-quote heredoc; $ is literal — correct for profile runtime)
$part2 = @'

function Load-SecretEnvironment {
    if (Get-Module -ListAvailable Microsoft.PowerShell.SecretStore) {
        Get-SecretInfo -Vault LocalStore -ErrorAction SilentlyContinue | ForEach-Object {
            $name = $_.Name
            $val = Get-Secret -Name $name -AsPlainText -ErrorAction SilentlyContinue
            if ($val) { Set-Content -Path "Env:\$name" -Value $val }
        }
    }
}

Load-SecretEnvironment

function Sync-ApiKeys {
    $scriptPath = "$HOME\workspace\My_init_setting\windows\Start-Setup.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath -Update -SyncSecrets
    } else {
        Write-Host "Error: Could not find $scriptPath" -ForegroundColor Red
    }
}

function Setup-Windows {
    param(
        [switch]$Update,
        [switch]$SyncSecrets,
        [switch]$IncludeOffice,
        [switch]$Clinic,
        [switch]$DryRun,
        [switch]$ServerMode,
        [switch]$Aliases,
        [switch]$McpServers,
        [switch]$WindowsSettings,
        [switch]$Workspace
    )
    $scriptPath = "$HOME\workspace\My_init_setting\windows\Start-Setup.ps1"
    & $scriptPath @PSBoundParameters
}

function Get-SbxSandboxes {
    # sbx daemon が未起動だと "Starting ..." 等のメッセージが stdout に混じり、
    # ConvertFrom-Json がそのまま失敗するため、最初に JSON らしき行が現れる位置以降だけを抽出する。
    $sbxRaw = @(sbx ls --json 2>$null)
    $jsonStartLine = $sbxRaw | Where-Object { $_ -match '^\s*[\{\[]' } | Select-Object -First 1
    if (-not $jsonStartLine) { return @() }
    $startIndex = [array]::IndexOf($sbxRaw, $jsonStartLine)
    $sbxJson = ($sbxRaw[$startIndex..($sbxRaw.Count - 1)]) -join "`n"
    try {
        return @((ConvertFrom-Json $sbxJson).sandboxes)
    } catch {
        Write-Warning "sbx ls --json の出力を解析できませんでした: $_"
        return @()
    }
}

function claude {
    param(
        [Parameter(Position=0)]
        [string]$Directory = '.',
        [switch]$AsHost,
        [switch]$Rebuild,
        [switch]$Sbx,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )

    if ($Sbx) {
        $cols    = [Console]::WindowWidth
        $rows    = [Console]::WindowHeight
        $sbxDir  = (Get-Item $Directory).FullName
        $dirName = (Get-Item $sbxDir).Name.ToLower() -replace '[^a-z0-9.+\-]', '-'
        $sbxName = "claude-$dirName"
        $sbxList = Get-SbxSandboxes
        if (($sbxList | Where-Object { $_.name -eq $sbxName }).Count -eq 0) {
            Write-Host "Creating sandbox $sbxName..." -ForegroundColor Cyan
            sbx create -q --name $sbxName claude $sbxDir
            if ($LASTEXITCODE -ne 0) { Write-Error 'Failed to create sandbox'; return }
        }
        $sbxWorkdir = '/' + $sbxDir[0].ToString().ToLower() + ($sbxDir.Substring(2) -replace '\\', '/')
        sbx exec -it -e "TERM=xterm-256color" -e "COLUMNS=$cols" -e "LINES=$rows" -w $sbxWorkdir $sbxName claude --dangerously-skip-permissions @Rest
        return
    }

    if ($AsHost) {
        $exe = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue |
               Select-Object -First 1 -ExpandProperty Source
        if (-not $exe) { Write-Error 'claude not found on host'; return }
        & $exe @Rest
        return
    }

    $targetDir = (Get-Item $Directory).FullName

    if (Test-Path (Join-Path $targetDir '.devcontainer') -PathType Container) {
        $compose   = Join-Path $targetDir '.devcontainer\docker-compose.yml'
        $container = (Get-Item $targetDir).Name

        $status = docker inspect --format '{{.State.Status}}' $container 2>$null

        if ($Rebuild) {
            Write-Host "Rebuilding container..." -ForegroundColor Cyan
            docker compose -f $compose up --build -d
            if ($LASTEXITCODE -ne 0) { Write-Error 'Failed to rebuild container'; return }

            $ready = $false
            for ($i = 0; $i -lt 30; $i++) {
                $status = docker inspect --format '{{.State.Status}}' $container 2>$null
                if ($status -eq 'running') { $ready = $true; break }
                Start-Sleep -Seconds 2
            }
            if (-not $ready) {
                Write-Error "$container did not start"
                docker compose -f $compose logs node
                return
            }
        } elseif ($status -ne 'running') {
            Write-Host "Starting container..." -ForegroundColor Cyan
            docker compose -f $compose up -d
            if ($LASTEXITCODE -ne 0) { Write-Error 'Failed to start container'; return }

            $ready = $false
            for ($i = 0; $i -lt 30; $i++) {
                $status = docker inspect --format '{{.State.Status}}' $container 2>$null
                if ($status -eq 'running') { $ready = $true; break }
                Start-Sleep -Seconds 2
            }
            if (-not $ready) {
                Write-Error "$container did not start"
                docker compose -f $compose logs node
                return
            }
        } else {
            Write-Host "Container already running ($container)" -ForegroundColor Green
        }

        docker exec -it $container zellij @Rest
        return
    }

    Write-Host "No .devcontainer found -> sbx exec claude" -ForegroundColor Yellow
    $cols    = [Console]::WindowWidth
    $rows    = [Console]::WindowHeight
    $dirName = (Get-Item $targetDir).Name.ToLower() -replace '[^a-z0-9.+\-]', '-'
    $sbxName = "claude-$dirName"
    $sbxList = Get-SbxSandboxes
    if (($sbxList | Where-Object { $_.name -eq $sbxName }).Count -eq 0) {
        Write-Host "Creating sandbox $sbxName..." -ForegroundColor Cyan
        sbx create -q --name $sbxName claude $targetDir
        if ($LASTEXITCODE -ne 0) { Write-Error 'Failed to create sandbox'; return }
    }
    $sbxWorkdir = '/' + $targetDir[0].ToString().ToLower() + ($targetDir.Substring(2) -replace '\\', '/')
    sbx exec -it -e "TERM=xterm-256color" -e "COLUMNS=$cols" -e "LINES=$rows" -w $sbxWorkdir $sbxName claude @Rest
}
'@

$part2Clinic = @'
function Load-SecretEnvironment {
    if (Get-Module -ListAvailable Microsoft.PowerShell.SecretStore) {
        Get-SecretInfo -Vault LocalStore -ErrorAction SilentlyContinue | ForEach-Object {
            $name = $_.Name
            $val = Get-Secret -Name $name -AsPlainText -ErrorAction SilentlyContinue
            if ($val) { Set-Content -Path "Env:\$name" -Value $val }
        }
    }
}

Load-SecretEnvironment

function Setup-Windows {
    param(
        [switch]$Update,
        [switch]$SyncSecrets,
        [switch]$IncludeOffice,
        [switch]$Clinic,
        [switch]$DryRun,
        [switch]$ServerMode,
        [switch]$Aliases,
        [switch]$McpServers,
        [switch]$WindowsSettings,
        [switch]$Workspace
    )
    $scriptPath = "$HOME\workspace\My_init_setting\windows\Start-Setup.ps1"
    & $scriptPath @PSBoundParameters
}
'@

if ($ProfileType -eq 'Clinic') {
    $part1 = $part1Clinic
    $part2 = $part2Clinic
}

$managedSection = "$markerStart`n$part1`n$part2`n$markerEnd"

# Replace existing managed section or append to profile
$existingContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

if ($existingContent -and $existingContent -match [regex]::Escape($markerStart)) {
    $escapedStart = [regex]::Escape($markerStart)
    $escapedEnd = [regex]::Escape($markerEnd)
    $newContent = [regex]::Replace($existingContent, "(?s)$escapedStart.*?$escapedEnd", $managedSection)
}
elseif ($existingContent -and $existingContent.Trim()) {
    $newContent = $existingContent.TrimEnd() + "`n`n$managedSection`n"
}
else {
    $newContent = "$managedSection`n"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($profilePath, $newContent, $utf8NoBom)

Set-SecretStoreConfiguration -Authentication None -Interaction None -Confirm:$false

Write-Host "PowerShell profile updated (managed section replaced)." -ForegroundColor Green
Write-Host "Please restart PowerShell to apply the changes." -ForegroundColor Yellow
