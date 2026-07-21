#!/data/data/com.termux/files/usr/bin/bash
# set_mcp_servers.sh - Merge shared/mcp.d MCP server definitions into mcp-config.json at the project root
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MCP_DIR="$SCRIPT_DIR/../../../shared/mcp.d"
OUTPUT_PATH="$SCRIPT_DIR/../../../mcp-config.json"

if ! command -v jq &>/dev/null; then
    echo "--- Installing jq ---"
    if command -v pkg &>/dev/null; then
        pkg install -y jq
    else
        apt-get update -y && apt-get install -y jq
    fi
fi

if [ ! -d "$MCP_DIR" ]; then
    echo "Error: MCP directory not found: $MCP_DIR" >&2
    exit 1
fi

echo "[ Antigravity CLI ] Merging MCP servers from $MCP_DIR..."
jq -s 'reduce .[] as $f ({}; . * $f) | {"mcpServers": .}' "$MCP_DIR"/*.json > "$OUTPUT_PATH"

echo "Done: $(jq -r '.mcpServers | keys | join(", ")' "$OUTPUT_PATH") -> $OUTPUT_PATH"
