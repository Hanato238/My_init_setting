# LocalStore ボールトが未登録なら登録
if (-not (Get-SecretVault -Name LocalStore -ErrorAction SilentlyContinue)) {
  Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
  Write-Host "Registered: LocalStore"
}
else {
  Write-Host "Skip: LocalStore already registered"
}
Set-SecretStoreConfiguration -Authentication None -Interaction None

# Bitwarden のログイン状態を確認し、必要なら login → unlock
$bwStatus = (bw status | ConvertFrom-Json).status
if ($bwStatus -eq "unauthenticated") {
  Write-Host "Not logged in. Running bw login..."
  bw login
}
$env:BW_SESSION = (bw unlock --raw)
if (-not $env:BW_SESSION) {
  Write-Error "Failed to get Bitwarden session. Aborting."
  exit 1
}

# オンラインと同期
bw sync --session $env:BW_SESSION

# フォルダ「security_keys」のIDを取得
$folderId = (bw list folders --session $env:BW_SESSION | ConvertFrom-Json | Where-Object { $_.name -eq "security_keys" }).id

if (-not $folderId) {
    Write-Error "Bitwarden folder 'security_keys' not found."
    exit 1
}

Write-Host "Fetching all items from folder 'security_keys'..."
$items = bw list items --folderid $folderId --session $env:BW_SESSION | ConvertFrom-Json

foreach ($item in $items) {
    $secretName = $item.name
    # パスワード欄、またはフィールド（あれば）から値を取得
    $value = $item.login.password
    if (-not $value -and $item.fields) {
        $value = ($item.fields | Where-Object { $_.name -eq "value" -or $_.name -eq "api_key" }).value
    }
    
    if ($value) {
        Set-Secret -Name $secretName -Secret $value -Vault LocalStore
        Write-Host "Saved: $secretName"
    }
    else {
        Write-Warning "Item '$secretName' has no password or valid custom field. Skipping."
    }
}

Write-Host "Done: secrets from 'security_keys' saved to SecretStore."
