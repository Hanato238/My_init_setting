# Run PowerShell as Administrator before executing this script

param(
    [switch]$Update,
    [switch]$SyncSecrets,
    [switch]$IncludeOffice,
    [switch]$DryRun
)

Set-ExecutionPolicy Bypass -Scope Process -Force

# iex (iwr ...) で実行された場合 $PSScriptRoot が空になるため、
# リポジトリ全体をダウンロードしてローカルから再実行する
if (-not $PSScriptRoot) {
    $tempDir = Join-Path $env:TEMP "My_init_setting"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }

    Write-Host "Downloading repository..." -ForegroundColor Yellow
    $zipPath = "$tempDir.zip"
    Invoke-WebRequest -Uri "https://github.com/Hanato238/My_init_setting/archive/refs/heads/main.zip" -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force
    Remove-Item $zipPath
    Rename-Item "$env:TEMP\My_init_setting-main" $tempDir

    $argList = @()
    if ($Update)        { $argList += '-Update' }
    if ($SyncSecrets)   { $argList += '-SyncSecrets' }
    if ($IncludeOffice) { $argList += '-IncludeOffice' }
    if ($DryRun)        { $argList += '-DryRun' }

    Write-Host "Restarting from local copy..." -ForegroundColor Yellow
    & "$tempDir\windows\Start-Setup.ps1" @argList
    return
}

# --- Main logic ---

$results = @()

function Add-Result([string]$Script, [string]$Status, [string]$Message) {
    $script:results += @{ Script = $Script; Status = $Status; Message = $Message }
}

function Invoke-Script([string]$Name, [string]$Path, [hashtable]$Params, [bool]$SupportsDryRun = $true) {
    if ($null -eq $Params) { $Params = @{} }
    if (-not (Test-Path $Path)) {
        Add-Result $Name 'WARN' 'script not found, skipped'
        Write-Warning "Script not found, skipping: $Path"
        return
    }
    if ($DryRun -and -not $SupportsDryRun) {
        Add-Result $Name 'WARN' 'no DryRun support, skipped'
        Write-Host "`n[DRY RUN] Skipping $Name (no DryRun support)" -ForegroundColor Yellow
        return
    }
    Write-Host "`n=== Running: $Name ===" -ForegroundColor Cyan
    try {
        & $Path @Params
        Add-Result $Name 'OK' ''
    } catch {
        Add-Result $Name 'ERR' $_.Exception.Message
        Write-Warning "Error in ${Name}: $_"
    }
}

if ($Update) {
    Invoke-Script 'Install-Apps.ps1'        "$PSScriptRoot\installer\Install-Apps.ps1"        @{ Update = $true; DryRun = $DryRun }
    if ($SyncSecrets) {
        Invoke-Script 'Initialize-Security.ps1' "$PSScriptRoot\installer\Initialize-Security.ps1" @{ DryRun = $DryRun }
    }
    Invoke-Script 'Setup-Wsl.ps1'           "$PSScriptRoot\installer\Setup-Wsl.ps1"           @{ Update = $true; DryRun = $DryRun }
    Invoke-Script 'Set-Aliases.ps1'         "$PSScriptRoot\settings\Set-Aliases.ps1"          @{} -SupportsDryRun $false
    Invoke-Script 'Set-McpServers.ps1'      "$PSScriptRoot\settings\Set-McpServers.ps1"       @{ DryRun = $DryRun }
    Invoke-Script 'Set-WindowsSettings.ps1' "$PSScriptRoot\settings\Set-WindowsSettings.ps1"  @{ DryRun = $DryRun }
} else {
    Invoke-Script 'Install-Chocolatey.ps1'  "$PSScriptRoot\installer\Install-Chocolatey.ps1"  @{} -SupportsDryRun $false
    Invoke-Script 'Install-Apps.ps1'        "$PSScriptRoot\installer\Install-Apps.ps1"        @{ DryRun = $DryRun }
    if ($IncludeOffice) {
        Invoke-Script 'Install-Office.ps1'  "$PSScriptRoot\installer\Install-Office.ps1"      @{ DryRun = $DryRun }
    } else {
        Add-Result 'Install-Office.ps1' 'WARN' 'skipped (use -IncludeOffice to install)'
    }
    if ($SyncSecrets) {
        Invoke-Script 'Initialize-Security.ps1' "$PSScriptRoot\installer\Initialize-Security.ps1" @{ DryRun = $DryRun }
    } else {
        Add-Result 'Initialize-Security.ps1' 'WARN' 'skipped (use -SyncSecrets to sync Bitwarden)'
    }
    Invoke-Script 'Setup-Wsl.ps1'           "$PSScriptRoot\installer\Setup-Wsl.ps1"           @{ DryRun = $DryRun }
    Invoke-Script 'Set-Aliases.ps1'         "$PSScriptRoot\settings\Set-Aliases.ps1"          @{} -SupportsDryRun $false
    Invoke-Script 'Set-McpServers.ps1'      "$PSScriptRoot\settings\Set-McpServers.ps1"       @{ DryRun = $DryRun }
    Invoke-Script 'Set-WindowsSettings.ps1' "$PSScriptRoot\settings\Set-WindowsSettings.ps1"  @{ DryRun = $DryRun }
    Invoke-Script 'Set-Workspace.ps1'       "$PSScriptRoot\settings\Set-Workspace.ps1"        @{} -SupportsDryRun $false
}

Write-Host "`n=== Setup Summary ===" -ForegroundColor Cyan
foreach ($r in $results) {
    $color = 'White'
    if ($r.Status -eq 'OK')   { $color = 'Green' }
    if ($r.Status -eq 'WARN') { $color = 'Yellow' }
    if ($r.Status -eq 'ERR')  { $color = 'Red' }
    $label = "[$($r.Status)]".PadRight(7)
    $msg = ''
    if ($r.Message) { $msg = "  - $($r.Message)" }
    Write-Host "$label $($r.Script)$msg" -ForegroundColor $color
}
