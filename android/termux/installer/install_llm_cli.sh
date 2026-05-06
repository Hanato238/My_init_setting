#!/data/data/com.termux/files/usr/bin/bash
# install_llm_cli.sh - Install gemini-cli and extensions optimized for Termux
set -e


pkg update -y
pkg install -y nodejs-lts python git vim zip uv

# Install CLIs
npm install -g @google/gemini-cli
npm install -g @anthropic-ai/claude-code

# Setup MCP servers repository
MCP_DIR="$HOME/workspace/mcp-servers"
if [ ! -d "$MCP_DIR" ]; then
    mkdir -p "$HOME/workspace"
    git clone https://github.com/Hanato238/mcp-servers.git "$MCP_DIR"
fi

cd "$MCP_DIR"
git pull
git submodule update --init --recursive

# Extension installation function
install_ext() {
    local ext_path="$1"
    local full_path="$MCP_DIR/$ext_path"
    
    if [ -d "$full_path" ]; then
        echo "--- Setting up extension: $ext_path ---"
        cd "$full_path"
        
        # Node.js
        if [ -f "package.json" ]; then
            npm install --silent
            if grep -q '"build":' "package.json"; then
                npm run build --silent
            fi
        fi
        
        # Python
        if [ -f "pyproject.toml" ]; then
            uv sync --quiet
        fi
        
        gemini extensions install . --consent
    else
        echo "Warning: Extension path not found: $full_path"
    fi
}

# List of extensions suitable for Termux
# (Excluded: brightdata, playwright, drawio, desktop-commander, openevidence)
EXTENSIONS=(
    "context7"
    "github"
    "google-workspace-cli"
    "hardening-agent"
    "observability"
    "todoist"
    "markitdown"
    "perplexity-mcp"
    "gyaru"
)

for ext in "${EXTENSIONS[@]}"; do
    install_ext "$ext"
done

# Standard MCPs
gemini mcp add filesystem npx -y @modelcontextprotocol/server-filesystem -s user
gemini mcp add memory npx -y @modelcontextprotocol/server-memory -s user
gemini mcp add sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking -s user
gemini mcp add fetch uvx mcp-server-fetch -s user
gemini mcp add git uvx mcp-server-git -s user

echo "LLM CLI environment setup complete."
