param(
    [switch]$DryRun,
    # Non-secret. Bitwarden Secrets Manager project name or GUID to pull from.
    # Empty = every secret the machine account can read (fine with a single project).
    [string]$BwsProject = $env:BWS_PROJECT
)

# Force UTF8 encoding for bws CLI output
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Setup SecretStore
if (-not (Get-Module -ListAvailable Microsoft.PowerShell.SecretStore)) {
    Write-Error "SecretStore module not found."
    return
}
if (-not (Get-SecretVault -Name LocalStore -ErrorAction SilentlyContinue)) {
    Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
}
Set-SecretStoreConfiguration -Authentication None -Interaction None -Confirm:$false

# 2. Locate the bws binary (cargo installs it under %USERPROFILE%\.cargo\bin,
#    which is not on PATH until the shell is reopened)
if (-not (Get-Command bws -ErrorAction SilentlyContinue)) {
    $cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
    if (Test-Path (Join-Path $cargoBin 'bws.exe')) {
        $env:PATH = "$cargoBin;$env:PATH"
    } else {
        Write-Error "bws not found. Run Start-Setup.ps1 first (installs it via cargo)."
        return
    }
}

# 3. Access token. A machine-account token grants read access to one Secrets
#    Manager project - never the personal vault. It is used from the environment
#    (CI) or pasted interactively, and is NOT persisted anywhere.
$tokenFromPrompt = $false
if ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
    $secure = Read-Host -AsSecureString "Bitwarden Secrets Manager access token"
    $env:BWS_ACCESS_TOKEN = [System.Net.NetworkCredential]::new('', $secure).Password
    $tokenFromPrompt = $true
}
if ([string]::IsNullOrWhiteSpace($env:BWS_ACCESS_TOKEN)) {
    Write-Error "No access token supplied."
    return
}

try {
    # Verify auth early for a clean error message
    bws project list -o none 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "bws authentication failed. Check the access token."
        return
    }

    # 4. Resolve the optional project filter (accepts a name or a GUID)
    $projectArg = @()
    if ($BwsProject) {
        if ($BwsProject -match '^[0-9a-fA-F-]{36}$') {
            $projectArg = @($BwsProject)
        } else {
            $proj = bws project list -o json | Out-String | ConvertFrom-Json |
                    Where-Object { $_.name -eq $BwsProject } | Select-Object -First 1
            if (-not $proj) { Write-Error "Secrets Manager project '$BwsProject' not found."; return }
            $projectArg = @($proj.id)
        }
    }

    # 5. Fetch secrets. Secrets Manager entries carry a real key/value pair, so
    #    the old login.password / notes / custom-field fallback chain is gone.
    $secrets = @(bws secret list @projectArg -o json | Out-String | ConvertFrom-Json)
    Write-Host "Found $($secrets.Count) secret(s) in Secrets Manager." -ForegroundColor Gray

    $savedList = @()
    foreach ($s in $secrets) {
        $secretName  = $s.key
        $secretValue = $s.value
        if ([string]::IsNullOrWhiteSpace($secretName) -or $null -eq $secretValue) { continue }
        if ($secretName -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            Write-Warning "Skipping '$secretName': not a valid environment variable name."
            continue
        }

        if ($DryRun) {
            Write-Host "[DRY RUN] Would save: $secretName" -ForegroundColor Yellow
        } else {
            Set-Secret -Name $secretName -Secret $secretValue -Vault LocalStore -Confirm:$false
            Write-Host "Success: $secretName"
        }
        $savedList += $secretName
    }
}
finally {
    # Drop the token so it does not linger in the caller's session
    if ($tokenFromPrompt) { Remove-Item Env:\BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue }
}

# 6. Final Summary
Write-Host "`n--- Final Summary ---" -ForegroundColor Green
if ($savedList.Count -gt 0) {
    $savedList | Sort-Object -Unique | ForEach-Object { Write-Host " [+] $_" }
    $action = if ($DryRun) { "would be updated" } else { "updated" }
    Write-Host "`nTotal: $($savedList.Count) secrets $action in SecretStore." -ForegroundColor Green
} else {
    Write-Host "No valid secrets were found to save." -ForegroundColor Yellow
}
Write-Host "Execution finished."
