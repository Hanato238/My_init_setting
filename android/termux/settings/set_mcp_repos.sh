#!/data/data/com.termux/files/usr/bin/bash
# set_mcp_repos.sh - Configures Gemini CLI using .mcp.json using jq
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="${1:-$SCRIPT_DIR/.mcp.json}"
GEMINI_PATH="$HOME/.gemini/settings.json"

if [ ! -f "$CONFIG_PATH" ]; then
    echo "Error: Configuration file not found at $CONFIG_PATH"
    exit 1
fi

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

echo "[ Gemini ] Applying MCP configurations from $CONFIG_PATH using jq..."

# 1. Read .mcp.json
# 2. Use envsubst-like behavior with jq or shell to expand env vars
# 3. Merge into ~/.gemini/settings.json

# We use python only for a quick env expansion if envsubst is not available, 
# but let's try to do as much as possible with jq.
# Since jq doesn't natively expand shell env vars easily without passing them one by one,
# we'll use a simple 'envsubst' pattern or a tiny python one-liner for just the string expansion
# if we want to keep it robust. 

# Expand environment variables in the config file
EXPANDED_CONFIG=$(python3 -c 'import os, sys, re; print(re.sub(r"\$\{(\w+)\}|\$(\w+)", lambda m: os.environ.get(m.group(1) or m.group(2), m.group(0)), sys.stdin.read()))' < "$CONFIG_PATH")

# Use jq to merge the expanded config into the settings file
# Note: we use --argjson to pass the expanded content to jq
NEW_SETTINGS=$(jq --argjson new "$EXPANDED_CONFIG" '.mcpServers += ($new.mcpServers // {})' "$GEMINI_PATH")

echo "$NEW_SETTINGS" > "$GEMINI_PATH"

# List added servers for confirmation
ADDED_SERVERS=$(echo "$EXPANDED_CONFIG" | jq -r '.mcpServers | keys | join(", ")')
echo "Successfully updated/added servers: $ADDED_SERVERS"
echo "Done: MCP servers have been integrated into ~/.gemini/settings.json"
