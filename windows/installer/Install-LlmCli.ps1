Set-ExecutionPolicy Bypass -Scope Process -Force

# install cli tools
npm install -g @anthropic-ai/claude-code -y
npm install -g @anthropic-ai/sdk -y
npm install -g @google/gemini-cli -y
refreshenv

# === Standard MCP servers ===

# Gemini
gemini mcp add filesystem npx @modelcontextprotocol/server-filesystem -s user
gemini mcp add memory npx @modelcontextprotocol/server-memory -s user
gemini mcp add sequential-thinking npx @modelcontextprotocol/server-sequential-thinking -s user
gemini mcp add fetch uvx mcp-server-fetch -s user
gemini mcp add git uvx mcp-server-git -s user

# Claude
claude mcp add filesystem -s user -- npx @modelcontextprotocol/server-filesystem
claude mcp add memory -s user -- npx @modelcontextprotocol/server-memory
claude mcp add sequential-thinking -s user -- npx @modelcontextprotocol/server-sequential-thinking
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

# === Env vars required by specific Claude MCP servers ===
# Add entries here for servers that need environment variables.
$claudeMcpEnv = @{
    "brightdata"   = @{ "API_TOKEN"          = $env:BRIGHTDATA_API_TOKEN }
    "perplexity"   = @{ "PERPLEXITY_API_KEY" = $env:PERPLEXITY_API_KEY }
    "openevidence" = @{ "OE_MCP_ROOT_DIR"    = "$env:USERPROFILE\.openevidence-mcp" }
}

# === Install extension: build + register to Gemini and Claude ===
function Install-Extension($path) {
    $fullPath = Join-Path $mcpServersDir $path
    if (-not (Test-Path $fullPath)) {
        Write-Warning "Extension path not found: $fullPath"
        return
    }

    Write-Host "`n--- Setting up extension: $path ---"
    Set-Location $fullPath

    # Build phase (shared)
    $pkg = $null
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

    # Register to Claude: detect entry point from local project files
    # Server name: lowercase directory name, strip trailing -mcp suffix
    $serverName = (Split-Path $path -Leaf).ToLower() -replace '-mcp$', ''

    $claudeCommand = $null
    $claudeArgs = @()

    if (Test-Path "package.json") {
        $entry = $null

        # Priority: bin > main > common build output locations
        if ($pkg.bin) {
            $entry = if ($pkg.bin -is [string]) { $pkg.bin }
                     else { ($pkg.bin.PSObject.Properties | Select-Object -First 1).Value }
        }
        if (-not $entry -and $pkg.main) { $entry = $pkg.main }
        foreach ($fallback in @("dist/index.js", "build/index.js", "index.js")) {
            if (-not $entry -and (Test-Path (Join-Path $fullPath $fallback))) {
                $entry = $fallback
            }
        }

        if ($entry -and (Test-Path (Join-Path $fullPath $entry))) {
            $claudeCommand = "node"
            $claudeArgs = @((Join-Path $fullPath $entry))
        } else {
            Write-Warning "  [Claude] No built entry point found for: $path"
        }
    } elseif (Test-Path "pyproject.toml") {
        $pyContent = Get-Content "pyproject.toml" -Raw
        if ($pyContent -match 'name\s*=\s*"([^"]+)"') {
            $claudeCommand = "uv"
            $claudeArgs = @("run", "--directory", $fullPath, $Matches[1])
        } else {
            Write-Warning "  [Claude] Could not parse module name from pyproject.toml: $path"
        }
    } else {
        Write-Warning "  [Claude] No package.json or pyproject.toml found: $path"
    }

    if (-not $claudeCommand) { return }

    # Build --env arguments from $claudeMcpEnv table
    $envArgs = @()
    if ($claudeMcpEnv.ContainsKey($serverName)) {
        foreach ($key in $claudeMcpEnv[$serverName].Keys) {
            $val = $claudeMcpEnv[$serverName][$key]
            if ($val) {
                $envArgs += '--env'
                $envArgs += "$key=$val"
            } else {
                Write-Warning "  [Claude] Env var '$key' for '$serverName' is not set"
            }
        }
    }

    & claude mcp add $serverName -s user @envArgs -- $claudeCommand @claudeArgs
    Write-Host "  [Claude] Registered: $serverName -> $claudeCommand $($claudeArgs -join ' ')"
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
