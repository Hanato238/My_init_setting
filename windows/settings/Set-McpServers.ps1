param(
  [string]$ServersPath    = "$PSScriptRoot\.mcp.json",
  [string]$ExtensionsPath = "$PSScriptRoot\.extensions.json",
  [string]$ClaudePath     = "$env:USERPROFILE\.claude.json",
  [string]$GeminiPath     = "$env:USERPROFILE\.gemini\settings.json"
)

$GeminiMcpKeys = @('git', 'fetch', 'memory', 'sequential-thinking')

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

function Write-Utf8NoBom($path, $lines) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, ($lines -join "`n") + "`n", $utf8NoBom)
}

# Claude Code: .mcp.json no all servers to ~/.claude.json
function Merge-ClaudeMcpServers($targetPath, $srcPath) {
  Ensure-JsonFile $targetPath
  $result = & jq --slurpfile src $srcPath '.mcpServers = ($src[0].mcpServers // {})' $targetPath
  if ($LASTEXITCODE -ne 0) { throw "jq failed to merge into $targetPath" }
  Write-Utf8NoBom $targetPath $result
}

# Gemini: filtered keys + time -> ~/.gemini/settings.json (PowerShell native to avoid Windows quote issues)
function Merge-GeminiMcpServers($targetPath, $srcPath, [string[]]$keys) {
  Ensure-JsonFile $targetPath

  $srcData    = Get-Content $srcPath    -Raw | ConvertFrom-Json
  $targetData = Get-Content $targetPath -Raw | ConvertFrom-Json

  $mcpServers = New-Object PSObject
  foreach ($k in $keys) {
    $val = $srcData.mcpServers.PSObject.Properties[$k].Value
    if ($null -ne $val) {
      $mcpServers | Add-Member -MemberType NoteProperty -Name $k -Value $val
    }
  }

  $timeServer = New-Object PSObject
  $timeServer | Add-Member -MemberType NoteProperty -Name 'type'    -Value 'stdio'
  $timeServer | Add-Member -MemberType NoteProperty -Name 'command' -Value 'uvx'
  $timeServer | Add-Member -MemberType NoteProperty -Name 'args'    -Value ([string[]]@('mcp-server-time'))
  $timeServer | Add-Member -MemberType NoteProperty -Name 'env'     -Value (New-Object PSObject)
  $mcpServers | Add-Member -MemberType NoteProperty -Name 'time' -Value $timeServer

  if ($targetData.PSObject.Properties['mcpServers']) {
    $targetData.mcpServers = $mcpServers
  } else {
    $targetData | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value $mcpServers
  }

  $json = $targetData | ConvertTo-Json -Depth 10
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($targetPath, $json + "`n", $utf8NoBom)
}

if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
  Write-Error "jq is required but not found in PATH."
  return
}

if (-not (Test-Path $ServersPath)) {
  Write-Error "Source MCP file not found: $ServersPath"
  return
}

$serverNames = (& jq -r '.mcpServers | keys[]' $ServersPath) -join ', '
Write-Host "[ Claude Code ] $ClaudePath"
Merge-ClaudeMcpServers $ClaudePath $ServersPath
Write-Host "Updated/Added: $serverNames"
Write-Host ""

Write-Host "[ Gemini MCP ] $GeminiPath"
Merge-GeminiMcpServers $GeminiPath $ServersPath $GeminiMcpKeys
Write-Host "Updated/Added: $($GeminiMcpKeys -join ', '), time"
Write-Host ""

if (Test-Path $ExtensionsPath) {
  Write-Host "[ Gemini Extensions ]"
  if (-not (Get-Command gemini -ErrorAction SilentlyContinue)) {
    Write-Warning "gemini command not found. Skipping extensions install."
  } else {
    $ext = Get-Content $ExtensionsPath -Raw | ConvertFrom-Json
    foreach ($category in $ext.PSObject.Properties) {
      Write-Host "  [$($category.Name)]"
      foreach ($url in $category.Value) {
        Write-Host "    Installing: $url"
        & gemini extensions install $url
      }
    }
  }
  Write-Host ""
}

Write-Host "Done: MCP servers and extensions have been configured." -ForegroundColor Green
