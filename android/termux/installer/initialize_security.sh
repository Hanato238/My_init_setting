#!/data/data/com.termux/files/usr/bin/bash
# initialize_security.sh - Sync Bitwarden secrets to local file
set -e

# Check requirements
if ! command -v bw &> /dev/null; then
    echo "Bitwarden CLI (bw) not found. Installing..."
    npm install -g @bitwarden/cli
fi

if ! command -v jq &> /dev/null; then
    echo "--- Installing jq ---"
    if command -v pkg &>/dev/null; then
        pkg install -y jq
    else
        apt-get update -y && apt-get install -y jq
    fi
fi

# Unlock session
BW_STATUS=$(bw status | jq -r '.status')
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

FOLDER_ID=$(bw list folders --session "$BW_SESSION" | jq -r --arg name "$FOLDER_NAME" '.[] | select(.name == $name) | .id')

if [ -z "$FOLDER_ID" ]; then
    echo "Error: Folder '$FOLDER_NAME' not found in Bitwarden."
    exit 1
fi

echo "Updating $SECRETS_FILE..."
bw list items --folderid "$FOLDER_ID" --session "$BW_SESSION" | jq -r '
    .[] |
    (.name | gsub("[^a-zA-Z0-9_]"; "_")) as $name |
    (.login.password // ([.fields[]? | select(.name as $n | ["value","api_key","secret","password","key"] | index($n))][0].value)) as $val |
    select($val != null and $val != "") |
    "export \($name)=\"\($val | gsub("\""; "\\\""))\""
' > "$SECRETS_FILE"

chmod 600 "$SECRETS_FILE"
echo "Security initialization finished. Secrets saved to $SECRETS_FILE."
