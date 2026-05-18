param(
  [string]$ServersPath = "$PSScriptRoot\.mcp.json",
  [string]$ClaudePath  = "$env:USERPROFILE\.claude.json"
)

function Ensure-JsonFile($path) {
  $dir = Split-Path $path
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  if (-not (Test-Path $path)) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, '{}', $utf8NoBom)
  }
}

function Merge-McpServers($targetPath, $srcPath) {
  Ensure-JsonFile $targetPath
  $jqFilter = '.mcpServers = ($src[0].mcpServers // {})'
  $result = & jq --slurpfile src $srcPath $jqFilter $targetPath
  if ($LASTEXITCODE -ne 0) {
    throw "jq failed to merge into $targetPath"
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($targetPath, ($result -join "`n") + "`n", $utf8NoBom)
}

if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
  Write-Error "jq is required but not found in PATH."
  return
}

if (-not (Test-Path $ServersPath)) {
  Write-Error "Source MCP file not found: $ServersPath"
  return
}

$serverNames = (& jq -r '.mcpServers | keys | join(", ")' $ServersPath)

Write-Host "[ Claude ] $ClaudePath"
Merge-McpServers $ClaudePath $ServersPath
Write-Host "Updated/Added: $serverNames"

Write-Host ""
Write-Host "Done: MCP servers have been merged." -ForegroundColor Green
