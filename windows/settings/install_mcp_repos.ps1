# install_mcp_repos.ps1 - Install Gemini CLI Extensions from repository
$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/Hanato238/mcp-servers.git"
$TargetDir = "$env:USERPROFILE\workspace\mcp-servers"

Write-Host "[ MCP ] Updating mcp-servers repository..."
if (-not (Test-Path "$env:USERPROFILE\workspace")) {
  New-Item -ItemType Directory -Path "$env:USERPROFILE\workspace" | Out-Null
}

if (Test-Path $TargetDir) {
  Set-Location $TargetDir
  git pull --recurse-submodules
}
else {
  git clone --recursive $RepoUrl $TargetDir
}

Write-Host "[ Gemini ] Scanning and installing extensions..."
# Find all directories with gemini-extension.json and install them
Get-ChildItem -Path $TargetDir -Filter "gemini-extension.json" -Recurse -Depth 3 | ForEach-Object {
    $dir = $_.DirectoryName
    $name = Split-Path $dir -Leaf
    Write-Host "  -> Installing extension: $name"
    # Ensure dependencies are installed for local build if needed (optional)
    if (Test-Path "$dir\package.json") {
        Push-Location $dir
        npm install --silent
        Pop-Location
    }
    # Run the official extension install command
    gemini extensions install $dir --force
}

Write-Host ""
Write-Host "Done: Extensions have been installed." -ForegroundColor Green
Write-Host "Next: Run '.\settings\set_mcp_servers.ps1' to add other standard MCP servers." -ForegroundColor Yellow
