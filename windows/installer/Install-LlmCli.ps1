Set-ExecutionPolicy Bypass -Scope Process -Force

# install cli tools
npm install -g @anthropic-ai/claude-code
npm install -g @google/gemini-cli -y
refreshenv

gemini mcp add filesystem npx -y @modelcontextprotocol/server-filesystem -s user
gemini mcp add memory npx -y @modelcontextprotocol/server-memory -s user
gemini mcp add sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking -s user
gemini mcp add fetch uvx mcp-server-fetch -s user
gemini mcp add git uvx mcp-server-git -s user

# install mcp-servers collection
$mcpServersDir = "$env:USERPROFILE\workspace\mcp-servers"
if (!(Test-Path $mcpServersDir)) {
    cd "$env:USERPROFILE\workspace"
    git clone https://github.com/Hanato238/mcp-servers.git
}
cd $mcpServersDir
git pull
git submodule update --init --recursive

# Function to install an extension
function Install-GeminiExtension($path) {
    $fullPath = Join-Path $mcpServersDir $path
    if (Test-Path $fullPath) {
        Write-Host "`n--- Setting up extension: $path ---"
        cd $fullPath
        
        # Setup Node.js projects
        if (Test-Path "package.json") {
            npm install --silent
            $pkg = Get-Content "package.json" | ConvertFrom-Json
            if ($pkg.scripts.build) {
                Write-Host "Building project..."
                npm run build --silent
            }
        }
        
        # Setup Python projects
        if (Test-Path "pyproject.toml") {
            Write-Host "Syncing uv environment..."
            uv sync --quiet
        }
        
        # Install to Gemini CLI
        gemini extensions install . --consent
    }
    else {
        Write-Warning "Extension path not found: $fullPath"
    }
}

# 1. Install Forked/Customized Extensions
$extensions = @(
    "brightdata",
    "drawio-mcp",
    "markitdown",
    "perplexity-mcp",
    "playwright-mcp",
    "serena",
    "openevidence-mcp",
    "notebooklm-mcp-cli"
)

# 3. Install other tools (without fork)
$extensions += @(
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
    Install-GeminiExtension $ext
}

# Special setup for OpenEvidence (Browsers)
cd (Join-Path $mcpServersDir "openevidence-mcp")
npx playwright install chromium

# Ensure NotebookLM tool is installed for CLI usage
uv tool install notebooklm-mcp-cli --force

cd "$env:USERPROFILE\workspace"
Write-Host "`n[SUCCESS] Gemini CLI extensions setup complete."
