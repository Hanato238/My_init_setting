param(
  [switch]$DryRun,
  [string]$McpDir          = "$PSScriptRoot\..\..\shared\mcp.d",
  [string]$ExtensionsPath  = "$PSScriptRoot\..\..\shared\.extensions.json",
  [string]$ClaudePath      = "$env:USERPROFILE\.claude.json",
  [string]$GeminiPath      = "$env:USERPROFILE\.gemini\settings.json"
)

$ClaudeMcpKeys = @('filesystem', 'git', 'fetch', 'memory', 'sequential-thinking')
$GeminiMcpKeys = @('filesystem', 'git', 'fetch', 'memory', 'sequential-thinking')

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

function Merge-McpDir($dirPath) {
  $combined = New-Object PSObject
  foreach ($file in Get-ChildItem $dirPath -Filter '*.json' | Sort-Object Name) {
    $data = Get-Content $file.FullName -Raw | ConvertFrom-Json
    foreach ($prop in $data.PSObject.Properties) {
      $combined | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
    }
  }
  return $combined
}

function Set-McpServers($targetPath, $srcServers, [string[]]$keys) {
  Ensure-JsonFile $targetPath
  $targetData = Get-Content $targetPath -Raw | ConvertFrom-Json

  $mcpServers = New-Object PSObject
  foreach ($k in $keys) {
    $val = $srcServers.PSObject.Properties[$k].Value
    if ($null -ne $val) {
      $mcpServers | Add-Member -MemberType NoteProperty -Name $k -Value $val
    }
  }

  if ($targetData.PSObject.Properties['mcpServers']) {
    $targetData.mcpServers = $mcpServers
  } else {
    $targetData | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value $mcpServers
  }

  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($targetPath, ($targetData | ConvertTo-Json -Depth 10) + "`n", $utf8NoBom)
}

if (-not (Test-Path $McpDir)) {
  Write-Error "MCP directory not found: $McpDir"
  return
}

# === Prerequisite tool installs ===
Write-Host "[ Prerequisite tools ]"
if ($DryRun) {
  Write-Host "[DRY RUN] npx playwright install chromium" -ForegroundColor Yellow
  Write-Host "[DRY RUN] uv tool install notebooklm-mcp-cli --force" -ForegroundColor Yellow
} else {
  npx playwright install chromium
  uv tool install notebooklm-mcp-cli --force
}
Write-Host ""

$allServers = Merge-McpDir $McpDir

Write-Host "[ Claude Code ] $ClaudePath"
Set-McpServers $ClaudePath $allServers $ClaudeMcpKeys
Write-Host "Updated/Added: $($ClaudeMcpKeys -join ', ')"
Write-Host ""

Write-Host "[ Gemini MCP ] $GeminiPath"
Set-McpServers $GeminiPath $allServers $GeminiMcpKeys
Write-Host "Updated/Added: $($GeminiMcpKeys -join ', ')"
Write-Host ""

if (Test-Path $ExtensionsPath) {
  Write-Host "[ Gemini Extensions ]"
  $ext = Get-Content $ExtensionsPath -Raw | ConvertFrom-Json
  if ($DryRun) {
    foreach ($category in $ext.PSObject.Properties) {
      Write-Host "  [$($category.Name)]"
      foreach ($url in $category.Value) {
        Write-Host "  [DRY RUN] gemini extensions install $url" -ForegroundColor Yellow
      }
    }
  } elseif (-not (Get-Command gemini -ErrorAction SilentlyContinue)) {
    Write-Warning "gemini command not found. Skipping extensions install."
  } else {
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
