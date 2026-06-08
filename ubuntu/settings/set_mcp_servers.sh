#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$SCRIPT_DIR/../../shared/mcp.d"

if [[ -n "${2:-}" ]]; then
  CLAUDE_PATH="$2"
elif [[ -n "${SUDO_USER:-}" ]]; then
  ACTUAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  CLAUDE_PATH="$ACTUAL_HOME/.claude.json"
else
  CLAUDE_PATH="$HOME/.claude.json"
fi

CLAUDE_KEYS='["filesystem","git","fetch","memory","sequential-thinking"]'

ensure_json_file() {
  local path="$1"
  local dir
  dir="$(dirname "$path")"
  if [[ -n "$dir" && ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
  if [[ ! -f "$path" ]]; then
    printf '{}' > "$path"
  fi
}

merge_mcp_servers() {
  local target_path="$1"
  local src_json="$2"
  ensure_json_file "$target_path"
  local result
  result=$(jq --argjson src "$src_json" --argjson keys "$CLAUDE_KEYS" \
    '.mcpServers = ($src.mcpServers // {} | with_entries(select(.key as $k | $keys | contains([$k]))))' \
    "$target_path")
  printf '%s\n' "$result" > "$target_path"
}

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -d "$MCP_DIR" ]]; then
  echo "Error: MCP directory not found: $MCP_DIR" >&2
  exit 1
fi

# Merge all mcp.d JSON files into a combined mcpServers structure
combined_json=$(jq -s 'reduce .[] as $f ({}; . * $f) | {"mcpServers": .}' "$MCP_DIR"/*.json)

echo "[ Claude ] $CLAUDE_PATH"
merge_mcp_servers "$CLAUDE_PATH" "$combined_json"
echo "Updated/Added: $(echo "$combined_json" | jq -r --argjson keys "$CLAUDE_KEYS" '.mcpServers | with_entries(select(.key as $k | $keys | contains([$k]))) | keys | join(", ")')"

echo ""
echo "Done: MCP servers have been merged."
