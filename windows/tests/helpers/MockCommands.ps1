# 外部コマンドのスタブ定義。
# Pester テスト内で dot-source して使う。
# Pester の Mock {} が使える場合はそちらを優先すること。

function winget   { Write-Host "MOCK: winget $args" }
function choco    { Write-Host "MOCK: choco $args" }
function nvm      { Write-Host "MOCK: nvm $args" }
function npm      { Write-Host "MOCK: npm $args" }
function bw       { Write-Host "MOCK: bw $args" }
function jq       { Write-Host "MOCK: jq $args" }
function claude   { Write-Host "MOCK: claude $args" }
function gemini   { Write-Host "MOCK: gemini $args" }
function refreshenv { Write-Host "MOCK: refreshenv" }
function uv       { Write-Host "MOCK: uv $args" }
function npx      { Write-Host "MOCK: npx $args" }
function git      { Write-Host "MOCK: git $args" }

function Install-Module {
    param([string]$Name, [switch]$Force, [string]$Scope, [switch]$SkipPublisherCheck)
    Write-Host "MOCK: Install-Module $Name"
}
function Register-SecretVault {
    param([string]$Name, [string]$ModuleName, [switch]$DefaultVault)
    Write-Host "MOCK: Register-SecretVault $Name"
}
function Set-SecretStoreConfiguration { Write-Host "MOCK: Set-SecretStoreConfiguration" }
function Get-SecretInfo               { return @() }
function Get-Secret                   { return $null }
function Set-Secret                   { Write-Host "MOCK: Set-Secret $args" }
