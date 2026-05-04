Set-ExecutionPolicy Bypass -Scope Process -Force

# install cli tools
npm install -g @anthropic-ai/claude-code
npm install -g @google/gemini-cli -y
refreshenv

# === Standard MCP servers ===

# Gemini
gemini mcp add filesystem npx -y @modelcontextprotocol/server-filesystem -s user
gemini mcp add memory npx -y @modelcontextprotocol/server-memory -s user
gemini mcp add sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking -s user
gemini mcp add fetch uvx mcp-server-fetch -s user
gemini mcp add git uvx mcp-server-git -s user

# Claude
claude mcp add filesystem -s user -- npx -y @modelcontextprotocol/server-filesystem
claude mcp add memory -s user -- npx -y @modelcontextprotocol/server-memory
claude mcp add sequential-thinking -s user -- npx -y @modelcontextprotocol/server-sequential-thinking
claude mcp add fetch -s user -- uvx mcp-server-fetch
claude mcp add git -s user -- uvx mcp-server-git

# === Clone/update Hanato238/mcp-servers ===
$mcpServersDir = "$env:USERPROFILE\workspace\mcp-servers"
if (!(Test-Path $mcpServersDir)) {
    cd "$env:USERPROFILE\workspace"
    git clone https://github.com/Hanato238/mcp-servers.git
}
cd $mcpServersDir
git pull
git submodule update --init --recursive

# === Install extension: build + register to Gemini and Claude ===
function Install-Extension($path) {
    $fullPath = Join-Path $mcpServersDir $path
    if (-not (Test-Path $fullPath)) {
        Write-Warning "Extension path not found: $fullPath"
        return
    }

    Write-Host "`n--- Setting up extension: $path ---"
    cd $fullPath

    # Build phase (shared)
    if (Test-Path "package.json") {
        npm install --silent
        $pkg = Get-Content "package.json" | ConvertFrom-Json
        if ($pkg.scripts.build) {
            Write-Host "Building project..."
            npm run build --silent
        }
    }
    if (Test-Path "pyproject.toml") {
        Write-Host "Syncing uv environment..."
        uv sync --quiet
    }

    # Register to Gemini
    gemini extensions install . --consent

    # Register to Claude (read mcpServers from gemini-extension.json)
    $extFile = Join-Path $fullPath "gemini-extension.json"
    if (-not (Test-Path $extFile)) { return }

    $ext = Get-Content $extFile -Raw -Encoding utf8 | ConvertFrom-Json
    $dirFwd = $fullPath -replace '\\', '/'

    foreach ($serverName in $ext.mcpServers.PSObject.Properties.Name) {
        $server = $ext.mcpServers.$serverName

        # Resolve ${extensionPath} and ${/}
        $resolvedArgs = $server.args | ForEach-Object {
            $_ -replace '\$\{extensionPath\}\$\{/\}', "$dirFwd/" `
               -replace '\$\{extensionPath\}/', "$dirFwd/" `
               -replace '\$\{extensionPath\}', $dirFwd
        }

        # Resolve env vars like ${VAR_NAME}
        $envArgs = @()
        if ($server.env) {
            foreach ($envProp in $server.env.PSObject.Properties) {
                $envVal = [regex]::Replace($envProp.Value, '\$\{(\w+)\}', {
                    param($m)
                    $v = [System.Environment]::GetEnvironmentVariable($m.Groups[1].Value)
                    if ($v) { $v } else { $m.Value }
                })
                $envArgs += @("-e", "$($envProp.Name)=$envVal")
            }
        }

        Write-Host "  [Claude] Adding MCP server: $serverName"
        & claude (@("mcp", "add", $serverName) + $envArgs + @("-s", "user", "--", $server.command) + $resolvedArgs)
    }
}

$extensions = @(
    "brightdata",
    "drawio-mcp",
    "markitdown",
    "perplexity-mcp",
    "playwright-mcp",
    "serena",
    "openevidence-mcp",
    "notebooklm-mcp-cli",
    "context7",
    "desktop-commander",
    "Figma",
    "github",
    "google-maps-platform",
    "google-workspace-cli",
    "hardening-agent",
    "huggingface",
    "observability",
    "youtube"
)

foreach ($ext in $extensions) {
    Install-Extension $ext
}

# Special setup for OpenEvidence (requires Chromium)
cd (Join-Path $mcpServersDir "openevidence-mcp")
npx playwright install chromium

# NotebookLM CLI tool
uv tool install notebooklm-mcp-cli --force

cd "$env:USERPROFILE\workspace"
Write-Host "`n[SUCCESS] LLM CLI setup complete. (Gemini + Claude)"
