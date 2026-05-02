#!/data/data/com.termux/files/usr/bin/bash
# setup_security.sh - Fetches secrets from Bitwarden and saves to ~/.secrets
set -e

# Check if bw is installed
if ! command -v bw &> /dev/null; then
    echo "Error: Bitwarden CLI (bw) is not installed."
    echo "Please install it first: pkg install nodejs-lts && npm install -g @bitwarden/cli"
    exit 1
fi

# Bitwarden Login/Unlock logic
# Use python3 to parse status since jq might be missing
STATUS=$(bw status | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', 'unauthenticated'))")

if [ "$STATUS" = "unauthenticated" ]; then
    echo "Not logged in. Running bw login..."
    bw login
fi

# Ensure session is unlocked
BW_SESSION=$(bw unlock --raw)
if [ -z "$BW_SESSION" ]; then
    echo "Error: Failed to get Bitwarden session."
    exit 1
fi
export BW_SESSION

# オンラインと同期
echo "Syncing Bitwarden..."
bw sync --session "$BW_SESSION"

SECRETS_FILE="$HOME/.secrets"
echo "Writing secrets from folder 'security_keys' to $SECRETS_FILE..."

# フォルダ「security_keys」のアイテムを全取得して export 形式で保存
# Python を使用して JSON を安全にパースし、環境変数定義を生成します
FOLDER_ID=$(bw list folders --session "$BW_SESSION" | python3 -c "import sys, json; print(next((f['id'] for f in json.load(sys.stdin) if f['name'] == 'security_keys'), ''))")

if [ -z "$FOLDER_ID" ]; then
    echo "Error: Bitwarden folder 'security_keys' not found."
    exit 1
fi

bw list items --folderid "$FOLDER_ID" --session "$BW_SESSION" | python3 -c "
import sys, json
items = json.load(sys.stdin)
for item in items:
    name = item.get('name')
    # パスワード、または特定のカスタムフィールドから値を取得
    val = item.get('login', {}).get('password')
    if not val and item.get('fields'):
        val = next((f.get('value') for f in item['fields'] if f.get('name') in ['value', 'api_key']), None)
    
    if val:
        # 特殊文字をエスケープして export 文を生成
        print(f'export {name}=\"{val}\"')
" > "$SECRETS_FILE"

chmod 600 "$SECRETS_FILE"
echo ""
echo "Done: All secrets from 'security_keys' saved to $SECRETS_FILE (chmod 600)."
echo "Make sure your ~/.bash_profile sources this file."
