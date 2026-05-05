#!/data/data/com.termux/files/usr/bin/bash
# initialize_security.sh - Sync Bitwarden secrets to local file
set -e

# Check requirements
if ! command -v bw &> /dev/null; then
    echo "Bitwarden CLI (bw) not found. Installing..."
    npm install -g @bitwarden/cli
fi

# Unlock session
BW_STATUS=$(bw status | python3 -c "import sys, json; print(json.load(sys.stdin).get('status'))")
if [ "$BW_STATUS" = "unauthenticated" ]; then
    echo "Not logged in. Running bw login..."
    bw login
fi

SESSION=$(bw unlock --raw)
if [ -z "$SESSION" ]; then
    echo "Error: Bitwarden unlock failed."
    exit 1
fi
export BW_SESSION="$SESSION"

echo "Syncing Bitwarden..."
bw sync --session "$BW_SESSION" > /dev/null

# Process folder 'api_keys'
SECRETS_FILE="$HOME/.secrets"
FOLDER_NAME="api_keys"

FOLDER_ID=$(bw list folders --session "$BW_SESSION" | python3 -c "import sys, json; print(next((f['id'] for f in json.load(sys.stdin) if f['name'] == '$FOLDER_NAME'), ''))")

if [ -z "$FOLDER_ID" ]; then
    echo "Error: Folder '$FOLDER_NAME' not found in Bitwarden."
    exit 1
fi

echo "Updating $SECRETS_FILE..."
bw list items --folderid "$FOLDER_ID" --session "$BW_SESSION" | python3 -c "
import sys, json, re
items = json.load(sys.stdin)
for item in items:
    name = item.get('name', '')
    # Replace spaces, dashes, and other non-alphanumeric chars with underscores
    safe_name = re.sub(r'[^a-zA-Z0-9_]', '_', name)
    
    val = item.get('login', {}).get('password')
    if not val and item.get('fields'):
        val = next((f.get('value') for f in item['fields'] if f.get('name') in ['value', 'api_key', 'secret', 'password', 'key']), None)
    
    if val:
        # Escape double quotes in value if any
        safe_val = val.replace('\"', '\\\"')
        print(f'export {safe_name}=\"{safe_val}\"')
" > "$SECRETS_FILE"

chmod 600 "$SECRETS_FILE"
echo "Security initialization finished. Secrets saved to $SECRETS_FILE."
