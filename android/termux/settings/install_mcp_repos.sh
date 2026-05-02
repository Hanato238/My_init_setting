#!/data/data/com.termux/files/usr/bin/bash
set -e

# Repository URL
REPO_URL="https://github.com/Hanato238/mcp-servers.git"
TARGET_DIR="$HOME/workspace/mcp-servers"

echo "[ MCP ] Cloning/Updating mcp-servers repository..."
mkdir -p "$HOME/workspace"

if [ -d "$TARGET_DIR" ]; then
    echo "[ MCP ] Repository already exists. Updating..."
    cd "$TARGET_DIR"
    git pull --recurse-submodules
else
    git clone --recursive "$REPO_URL" "$TARGET_DIR"
fi

# Setup individual servers
setup_project() {
    local dir="$1"
    cd "$dir"
    
    # 1. Node.js Setup
    if [ -f "package.json" ]; then
        echo "[ MCP ] Setting up Node.js project: $(basename "$dir")"
        npm install --silent
        if grep -q '"build":' package.json; then
            npm run build --silent
        fi
    fi

    # 2. Python Setup (uv)
    if [ -f "pyproject.toml" ]; then
        echo "[ MCP ] Setting up Python project: $(basename "$dir")"
        uv sync --quiet
    fi

    # 3. Gemini Extension Setup
    if [ -f "gemini-extension.json" ]; then
        echo "[ Gemini ] Installing extension: $(basename "$dir")"
        gemini extensions install . --force
    fi
}

echo "[ MCP ] Scanning for sub-projects..."

# Iterate through each directory in the root
for d in "$TARGET_DIR"/*/; do
    [ -d "$d" ] || continue
    setup_project "$d"
done

# Handle specific nested projects
MARKITDOWN_MCP="$TARGET_DIR/markitdown/packages/markitdown-mcp"
if [ -d "$MARKITDOWN_MCP" ]; then
    setup_project "$MARKITDOWN_MCP"
fi

SECURITY_MCP="$TARGET_DIR/gemini-cli-security/mcp-server"
if [ -d "$SECURITY_MCP" ]; then
    setup_project "$SECURITY_MCP"
fi

echo ""
echo "Done: All MCP projects and extensions have been initialized."
echo "Run 'bash settings/set_mcp_servers.sh' to update your Gemini settings."
