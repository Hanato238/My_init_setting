param(
  [string]$ServersPath    = "$PSScriptRoot\.mcp.json",
  [string]$ExtensionsPath = "$PSScriptRoot\.extensions.json",
  [string]$ClaudePath     = "$env:USERPROFILE\.claude.json",
  [string]$GeminiPath     = "$env:USERPROFILE\.gemini\settings.json"
)

# Gemini に追加する MCP サーバーキー（.mcp.json から抽出）
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

# Claude Code: .mcp.json の全サーバーを ~/.claude.json にマージ
function Merge-ClaudeMcpServers($targetPath, $srcPath) {
  Ensure-JsonFile $targetPath
  $result = & jq --slurpfile src $srcPath '.mcpServers = ($src[0].mcpServers // {})' $targetPath
  if ($LASTEXITCODE -ne 0) { throw "jq failed to merge into $targetPath" }
  Write-Utf8NoBom $targetPath $result
}

# Gemini: 指定キーのみ + time サーバーを ~/.gemini/settings.json にマージ
function Merge-GeminiMcpServers($targetPath, $srcPath, [string[]]$keys) {
  Ensure-JsonFile $targetPath
  $inExpr = ($keys | ForEach-Object { '"' + $_ + '"' }) -join ','
  # jq フィルターをファイル経由で渡す（Windows での引数クォート問題を回避）
  $filterContent = '.mcpServers = (($src[0].mcpServers // {}) | with_entries(select(.key | IN(' + $inExpr + ')))) + {"time":{"type":"stdio","command":"uvx","args":["mcp-server-time"],"env":{}}}'
  $filterFile = [System.IO.Path]::GetTempFileName()
  try {
    [System.IO.File]::WriteAllText($filterFile, $filterContent, (New-Object System.Text.UTF8Encoding $false))
    $result = & jq --slurpfile src $srcPath -f $filterFile $targetPath
    if ($LASTEXITCODE -ne 0) { throw "jq failed to merge Gemini servers into $targetPath" }
    Write-Utf8NoBom $targetPath $result
  } finally {
    Remove-Item $filterFile -ErrorAction SilentlyContinue
  }
}

# --- 前提チェック ---
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
  Write-Error "jq is required but not found in PATH."
  return
}

if (-not (Test-Path $ServersPath)) {
  Write-Error "Source MCP file not found: $ServersPath"
  return
}

# --- Claude Code: 全サーバーをマージ ---
$serverNames = (& jq -r '.mcpServers | keys | join(", ")' $ServersPath)
Write-Host "[ Claude Code ] $ClaudePath"
Merge-ClaudeMcpServers $ClaudePath $ServersPath
Write-Host "Updated/Added: $serverNames"
Write-Host ""

# --- Gemini: 指定サーバー + time をマージ ---
Write-Host "[ Gemini MCP ] $GeminiPath"
Merge-GeminiMcpServers $GeminiPath $ServersPath $GeminiMcpKeys
Write-Host "Updated/Added: $($GeminiMcpKeys -join ', '), time"
Write-Host ""

# --- Gemini Extensions インストール ---
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
