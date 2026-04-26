Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force

# LocalStore ボールトが未登録なら登録
if (-not (Get-SecretVault -Name LocalStore -ErrorAction SilentlyContinue)) {
  Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
  Write-Host "Registered: LocalStore"
}
else {
  Write-Host "Skip: LocalStore already registered"
}

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

function Save-BwSecret($secretName) {
  $value = bw get password $secretName --session $env:BW_SESSION
  if (-not $value) {
    Write-Warning "Bitwarden item '$secretName' not found. Skipping."
    return
  }
  Set-Secret -Name $secretName -Secret $value -Vault LocalStore
  Write-Host "Saved: $secretName"
}

# SecretName = Bitwarden のアイテム名 兼 SecretStore の保存名
Save-BwSecret "PERPLEXITY_API_KEY"
Save-BwSecret "GITHUB_PERSONAL_ACCESS_TOKEN"
Save-BwSecret "BRIGHTDATA_API_TOKEN"
Save-BwSecret "HF_TOKEN"
Save-BwSecret "GW_MCP_CLIENT_ID"
Save-BwSecret "GW_MCP_CLIENT_SECRET"

Write-Host "Done: secrets saved to SecretStore."
