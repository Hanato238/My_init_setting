#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVERS_PATH="${1:-$SCRIPT_DIR/.mcp.json}"
if [[ -n "${2:-}" ]]; then
  CLAUDE_PATH="$2"
elif [[ -n "${SUDO_USER:-}" ]]; then
  ACTUAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  CLAUDE_PATH="$ACTUAL_HOME/.claude.json"
else
  CLAUDE_PATH="$HOME/.claude.json"
fi

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
  local src_path="$2"
  ensure_json_file "$target_path"
  local result
  result=$(jq --slurpfile src "$src_path" '.mcpServers = ($src[0].mcpServers // {})' "$target_path")
  printf '%s\n' "$result" > "$target_path"
}

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$SERVERS_PATH" ]]; then
  echo "Error: Source MCP file not found: $SERVERS_PATH" >&2
  exit 1
fi

server_names=$(jq -r '.mcpServers | keys | join(", ")' "$SERVERS_PATH")

echo "[ Claude ] $CLAUDE_PATH"
merge_mcp_servers "$CLAUDE_PATH" "$SERVERS_PATH"
echo "Updated/Added: $server_names"

echo ""
echo "Done: MCP servers have been merged."
