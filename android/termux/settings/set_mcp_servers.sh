#!/data/data/com.termux/files/usr/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVERS_PATH="${1:-$SCRIPT_DIR/mcp_servers.json}"
GEMINI_PATH="$HOME/.gemini/settings.json"

mkdir -p "$HOME/.gemini"

python3 - "$SERVERS_PATH" "$GEMINI_PATH" << 'PYEOF'
import json, sys, os, re

servers_path, gemini_path = sys.argv[1], sys.argv[2]

with open(servers_path, encoding="utf-8") as f:
    raw = f.read()

# Expand $HOME placeholder
raw = raw.replace("$HOME", os.environ["HOME"])
src = json.loads(raw)

if os.path.exists(gemini_path):
    with open(gemini_path, encoding="utf-8") as f:
        gemini = json.load(f)
else:
    gemini = {}

action = "overwrite" if "mcpServers" in gemini else "add"
gemini["mcpServers"] = src["mcpServers"]

with open(gemini_path, "w", encoding="utf-8") as f:
    json.dump(gemini, f, indent=2, ensure_ascii=False)

print(f"[ Gemini ] {gemini_path}")
print(f"{action}: {', '.join(src['mcpServers'].keys())}")
PYEOF

echo ""
echo "Done: MCP servers have been written to ~/.gemini/settings.json"
