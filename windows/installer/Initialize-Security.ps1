# Force UTF8 encoding for Bitwarden CLI output
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Setup SecretStore
if (-not (Get-Module -ListAvailable Microsoft.PowerShell.SecretStore)) {
    Write-Error "SecretStore module not found."
    exit 1
}
if (-not (Get-SecretVault -Name LocalStore -ErrorAction SilentlyContinue)) {
    Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
}
Set-SecretStoreConfiguration -Authentication None -Interaction None

# 2. Bitwarden Unlock
[string]$session = (bw unlock --raw).Trim()
if (-not $session) {
    Write-Error "Bitwarden unlock failed."
    exit 1
}
$env:BW_SESSION = $session
Write-Host "Syncing Bitwarden..." -ForegroundColor Gray
bw sync --session $env:BW_SESSION | Out-Null

# 3. Get Folder IDs
$foldersJson = bw list folders --session $env:BW_SESSION | Out-String
$targetFolders = $foldersJson | ConvertFrom-Json | Where-Object { $_.name -eq "api_keys" }

if (-not $targetFolders) {
    Write-Error "Folder 'api_keys' not found."
    exit 1
}

$allFoundItems = @()
foreach ($folder in $targetFolders) {
    $fid = $folder.id
    Write-Host "Checking folder ID: $fid" -ForegroundColor Gray
    
    # Capture items as string first to ensure proper encoding handling
    $itemsJson = bw list items --folderid "$fid" --session "$env:BW_SESSION" | Out-String
    if ($itemsJson -and $itemsJson -ne "[]") {
        $itemsInFolder = $itemsJson | ConvertFrom-Json
        if ($itemsInFolder) {
            $allFoundItems += $itemsInFolder
        }
    }
}

Write-Host "Found $($allFoundItems.Count) items in total." -ForegroundColor Gray

# 4. Process Items
$savedList = @()
foreach ($item in $allFoundItems) {
    $secretName = $item.name
    $secretValue = $null

    # 1. Try Login Password
    if ($item.login -and $item.login.password) {
        $secretValue = $item.login.password
    }
    # 2. Try Secure Note content
    elseif ($item.notes) {
        $secretValue = $item.notes
    }
    # 3. Try Custom Fields
    if (-not $secretValue -and $item.fields) {
        $field = $item.fields | Where-Object { $_.name -match "value|api_key|secret|password|key" } | Select-Object -First 1
        if ($field) { $secretValue = $field.value }
    }

    if ($secretValue) {
        Set-Secret -Name $secretName -Secret $secretValue -Vault LocalStore -Confirm:$false
        Write-Host "Success: $secretName"
        $savedList += $secretName
    }
}

# 5. Final Summary
Write-Host "`n--- Final Summary ---" -ForegroundColor Green
if ($savedList.Count -gt 0) {
    $savedList | Sort-Object -Unique | ForEach-Object { Write-Host " [+] $_" }
    Write-Host "`nTotal: $($savedList.Count) secrets updated in SecretStore." -ForegroundColor Green
}
else {
    Write-Host "No valid secrets were found to save." -ForegroundColor Yellow
}
Write-Host "Execution finished."
