param([switch]$DryRun)

Set-ExecutionPolicy Bypass -Scope Process -Force

# --- CLI tools ---
if ($DryRun) {
    Write-Host "[DRY RUN] npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow
    Write-Host "[DRY RUN] npm install -g @anthropic-ai/sdk" -ForegroundColor Yellow
    Write-Host "[DRY RUN] npm install -g @google/gemini-cli" -ForegroundColor Yellow
} else {
    npm install -g @anthropic-ai/claude-code -y
    npm install -g @anthropic-ai/sdk -y
    npm install -g @google/gemini-cli -y
    refreshenv
}

# === Standard MCP servers ===

$stdServers = @(
    @{ tool = "gemini"; cmd = "npx"; pkg = "@modelcontextprotocol/server-filesystem"; name = "filesystem" }
    @{ tool = "gemini"; cmd = "npx"; pkg = "@modelcontextprotocol/server-memory";     name = "memory" }
    @{ tool = "gemini"; cmd = "npx"; pkg = "@modelcontextprotocol/server-sequential-thinking"; name = "sequential-thinking" }
    @{ tool = "gemini"; cmd = "uvx"; pkg = "mcp-server-fetch";                        name = "fetch" }
    @{ tool = "gemini"; cmd = "uvx"; pkg = "mcp-server-git";                          name = "git" }
    @{ tool = "claude"; cmd = "npx"; pkg = "@modelcontextprotocol/server-filesystem"; name = "filesystem" }
    @{ tool = "claude"; cmd = "npx"; pkg = "@modelcontextprotocol/server-memory";     name = "memory" }
    @{ tool = "claude"; cmd = "npx"; pkg = "@modelcontextprotocol/server-sequential-thinking"; name = "sequential-thinking" }
    @{ tool = "claude"; cmd = "uvx"; pkg = "mcp-server-fetch";                        name = "fetch" }
    @{ tool = "claude"; cmd = "uvx"; pkg = "mcp-server-git";                          name = "git" }
)

foreach ($s in $stdServers) {
    if ($DryRun) {
        Write-Host "[DRY RUN] $($s.tool) mcp add $($s.name) $($s.cmd) $($s.pkg)" -ForegroundColor Yellow
    } elseif ($s.tool -eq "gemini") {
        gemini mcp add $s.name $s.cmd $s.pkg -s user
    } else {
        claude mcp add $s.name -s user -- $s.cmd $s.pkg
    }
}

# === Clone/update Hanato238/mcp-servers ===
$mcpServersDir = "$env:USERPROFILE\workspace\mcp-servers"
if ($DryRun) {
    Write-Host "[DRY RUN] git clone https://github.com/Hanato238/mcp-servers.git (if not exists)" -ForegroundColor Yellow
    Write-Host "[DRY RUN] git pull + submodule update in $mcpServersDir" -ForegroundColor Yellow
} else {
    if (!(Test-Path $mcpServersDir)) {
        Set-Location "$env:USERPROFILE\workspace"
        git clone https://github.com/Hanato238/mcp-servers.git
    }
    Set-Location $mcpServersDir
    git pull
    git submodule update --init --recursive
}

# === Env vars required by specific Claude MCP servers ===
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

    if ($DryRun) {
        Write-Host "[DRY RUN] npm install / build in $fullPath" -ForegroundColor Yellow
        Write-Host "[DRY RUN] gemini extensions install $fullPath" -ForegroundColor Yellow
        Write-Host "[DRY RUN] claude mcp add (auto-detect entry point) in $fullPath" -ForegroundColor Yellow
        return
    }

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
    $serverName = (Split-Path $path -Leaf).ToLower() -replace '-mcp$', ''

    $claudeCommand = $null
    $claudeArgs = @()

    if (Test-Path "package.json") {
        $entry = $null

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
if ($DryRun) {
    Write-Host "[DRY RUN] npx playwright install chromium (openevidence-mcp)" -ForegroundColor Yellow
    Write-Host "[DRY RUN] uv tool install notebooklm-mcp-cli --force" -ForegroundColor Yellow
} else {
    Set-Location (Join-Path $mcpServersDir "openevidence-mcp")
    npx playwright install chromium
    uv tool install notebooklm-mcp-cli --force
    Set-Location "$env:USERPROFILE\workspace"
}

Write-Host "`n[SUCCESS] LLM CLI setup complete. (Gemini + Claude)"
