#!/data/data/com.termux/files/usr/bin/bash
# set_mcp_repos.sh - Configures Gemini CLI using Hanato238/mcp-servers and .mcp.json
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="${1:-$SCRIPT_DIR/.mcp.json}"
GEMINI_PATH="$HOME/.gemini/settings.json"
WORKSPACE_DIR="$HOME/workspace"
MCP_SERVERS_DIR="$WORKSPACE_DIR/mcp-servers"
REPO_URL="https://github.com/Hanato238/mcp-servers.git"

# List of specific extensions to install
TARGET_EXTENSIONS=(
    "gemini-cli-security"
    "google-workspace-cli"
    "google-maps-platform"
    "perplexity-mcp"
    "markitdown"
    "gyaru"
    "github"
    "todoist"
    "observability"
    "desktop-commander"
)

# 1. Setup Hanato238/mcp-servers repository
echo "[ Gemini ] Setting up mcp-servers repository in $MCP_SERVERS_DIR..."
mkdir -p "$WORKSPACE_DIR"

if [ ! -d "$MCP_SERVERS_DIR" ]; then
    echo "Cloning repository..."
    git clone "$REPO_URL" "$MCP_SERVERS_DIR"
    cd "$MCP_SERVERS_DIR"
    git submodule update --init --recursive
else
    echo "Repository already exists, pulling updates..."
    cd "$MCP_SERVERS_DIR"
    git pull
    git submodule update --init --recursive
fi

# 2. Install specific extensions using gemini extensions install
echo "[ Gemini ] Installing extensions..."
for ext in "${TARGET_EXTENSIONS[@]}"; do
    if [ -d "$MCP_SERVERS_DIR/$ext" ]; then
        echo "Installing extension: $ext"
        # Run gemini extensions install for the local directory
        # Using -y if available to skip confirmation, though standard command might not need it
        gemini extensions install "$MCP_SERVERS_DIR/$ext"
    else
        echo "Warning: Extension directory $ext not found in $MCP_SERVERS_DIR"
    fi
done

# 3. Handle .mcp.json fallback (existing logic)
if [ -f "$CONFIG_PATH" ]; then
    echo "[ Gemini ] Applying additional MCP configurations from $CONFIG_PATH using jq..."

    # Ensure jq is installed
    if ! command -v jq >/dev/null 2>&1; then
        echo "--- Installing jq ---"
        pkg install -y jq
    fi

    mkdir -p "$(dirname "$GEMINI_PATH")"

    # Initialize gemini settings if it doesn't exist
    if [ ! -f "$GEMINI_PATH" ]; then
        echo '{"mcpServers": {}}' > "$GEMINI_PATH"
    fi

    # Expand environment variables in the config file
    EXPANDED_CONFIG=$(python3 -c 'import os, sys, re; print(re.sub(r"\$\{(\w+)\}|\$(\w+)", lambda m: os.environ.get(m.group(1) or m.group(2), m.group(0)), sys.stdin.read()))' < "$CONFIG_PATH")

    # Use jq to merge the expanded config into the settings file
    NEW_SETTINGS=$(jq --argjson new "$EXPANDED_CONFIG" '.mcpServers += ($new.mcpServers // {})' "$GEMINI_PATH")

    echo "$NEW_SETTINGS" > "$GEMINI_PATH"

    # List added servers for confirmation
    ADDED_SERVERS=$(echo "$EXPANDED_CONFIG" | jq -r '.mcpServers | keys | join(", ")')
    echo "Successfully updated/added servers from config: $ADDED_SERVERS"
else
    echo "[ Gemini ] Skipping .mcp.json fallback (file not found at $CONFIG_PATH)"
fi

echo "Done: Setup complete!"
