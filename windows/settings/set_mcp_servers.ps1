param(
  [string]$ServersPath = "$env:USERPROFILE\workspace\My_init_setting/windows/settings/mcp_servers.json",
  [string]$ClaudePath = "$env:USERPROFILE\.claude.json",
  [string]$GeminiPath = "$env:USERPROFILE\.gemini\settings.json"
)

function Load-OrCreate($path) {
  if (Test-Path $path) {
    $content = [System.IO.File]::ReadAllText($path, (New-Object System.Text.UTF8Encoding $false))
    $content.TrimStart([char]0xFEFF) | ConvertFrom-Json
  }
  else {
    [PSCustomObject]@{}
  }
}

function Save-Json($obj, $path) {
  $dir = Split-Path $path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $tmp = [System.IO.Path]::GetTempFileName()
  try {
    $raw = $obj | ConvertTo-Json -Depth 10 -Compress
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tmp, $raw, $utf8NoBom)
    node -e "const fs=require('fs');const o=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));fs.writeFileSync(process.argv[2],JSON.stringify(o,null,2),'utf8')" $tmp $path
  }
  finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
}

# %USERPROFILE% を展開しながら mcp_servers.json を読み込む
$rawJson = (Get-Content $ServersPath -Raw -Encoding utf8) `
  -replace '%USERPROFILE%', ($env:USERPROFILE -replace '\\', '\\')
$src = $rawJson | ConvertFrom-Json

# --- Claude ---
Write-Host "[ Claude ] $ClaudePath"
$claude = Load-OrCreate $ClaudePath
if ($claude.PSObject.Properties['mcpServers']) {
  $claude.mcpServers = $src.mcpServers
  Write-Host "overwrite: $($src.mcpServers.PSObject.Properties.Name -join ', ')"
}
else {
  $claude | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value $src.mcpServers
  Write-Host "add: $($src.mcpServers.PSObject.Properties.Name -join ', ')"
}
Save-Json $claude $ClaudePath

# --- Gemini ---
Write-Host ""
Write-Host "[ Gemini ] $GeminiPath"
$gemini = Load-OrCreate $GeminiPath
if ($gemini.PSObject.Properties['mcpServers']) {
  $gemini.mcpServers = $src.mcpServers
  Write-Host "overwrite: $($src.mcpServers.PSObject.Properties.Name -join ', ')"
}
else {
  $gemini | Add-Member -MemberType NoteProperty -Name 'mcpServers' -Value $src.mcpServers
  Write-Host "add: $($src.mcpServers.PSObject.Properties.Name -join ', ')"
}
Save-Json $gemini $GeminiPath

Write-Host ""
Write-Host "Done: MCP servers have been overwritten." -ForegroundColor Green
