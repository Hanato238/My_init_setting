#!/bin/bash
set -e

BASHRC="$HOME/.bashrc"
MARKER_V1="# === WSL Aliases ==="
MARKER_V2="# === WSL Aliases v2 ==="

# Install wslu (provides wslview) if not present
if ! command -v wslview &>/dev/null; then
    sudo apt-get install -y wslu
fi

# Already on v2 - nothing to do
if grep -qF "$MARKER_V2" "$BASHRC"; then
    echo "Aliases already configured (v2) in $BASHRC"
    exit 0
fi

# v1 exists: append only new additions under v2 marker
if grep -qF "$MARKER_V1" "$BASHRC"; then
    cat >> "$BASHRC" << 'EOF'

# === WSL Aliases v2 ===

# Windows user home path (for WSL interop)
WIN_HOME=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')" 2>/dev/null || echo "/mnt/c/Users/lesen")

function qq()     { _open 'https://www.e-igakukai.jp/user_service/kaiin_portal/home/home.htm'; }

function claude() {
    read -rp "これはホスト環境です。実行しますか？(y/n): " response
    [[ "$response" =~ ^[Yy]$ ]] && command claude "$@"
}

function sbxcc() { sbx run claude "$@"; }
EOF
    echo "WSL Aliases v2 additions configured in $BASHRC"
    echo "Please restart your shell to apply changes."
    exit 0
fi

# Fresh install: append full block under v2 marker
cat >> "$BASHRC" << 'EOF'

# === WSL Aliases ===

# Open a URL in the Windows default browser
_open() { wslview "$1" 2>/dev/null || xdg-open "$1"; }

# Windows app shortcuts (WSL -> Windows executables)
alias chrome='"/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"'
alias vscode='"/mnt/c/Program Files/Microsoft VS Code/Code.exe"'
alias docker-desktop='"/mnt/c/Program Files/Docker/Docker/Docker Desktop.exe"'
alias powerpoint='"/mnt/c/Program Files/Microsoft Office/root/Office16/POWERPNT.EXE"'
alias word='"/mnt/c/Program Files/Microsoft Office/root/Office16/WINWORD.EXE"'
alias excel='"/mnt/c/Program Files/Microsoft Office/root/Office16/EXCEL.EXE"'
alias onenote='"/mnt/c/Program Files/Microsoft Office/root/Office16/ONENOTE.EXE"'
alias outlook='"/mnt/c/Program Files/Microsoft Office/root/Office16/OUTLOOK.EXE"'

# URL shortcuts
function chatgpt()       { _open 'https://chat.openai.com/'; }
function gemini-chrome() { _open 'https://gemini.google.com/app'; }
function claude-chrome() { _open 'https://claude.ai/'; }
function pplx-chrome()   { _open 'https://www.perplexity.ai/'; }
function nlm-chrome()    { _open 'https://notebooklm.google.com/'; }
function hf-chrome()     { _open 'https://huggingface.co/'; }
function context7()      { _open 'https://context7.com/dashboard'; }
function github()        { _open 'https://github.com/'; }
function gdrive()        { _open 'https://drive.google.com/drive/'; }
function gmail()         { _open 'https://mail.google.com/mail/u/0/?tab=rm&ogbl#inbox'; }
function gcp()           { _open 'https://console.cloud.google.com/welcome?hl=ja'; }
function gai()           { _open 'https://aistudio.google.com/app/prompts/new_chat'; }
function linedev()       { _open 'https://developers.line.biz/console/'; }
function lineoam()       { _open 'https://manager.line.biz/'; }
function openai()        { _open 'https://platform.openai.com/settings/organization/general'; }
function phantomjs()     { _open 'https://dashboard.phantomjscloud.com/dash.html'; }
function tencentc()      { _open 'https://www.tencentcloud.com/'; }
function rainio()        { _open 'https://app.raindrop.io/my/0'; }
function youtube()       { _open 'https://www.youtube.com/'; }
function mf()            { _open 'https://moneyforward.com/'; }
function oe()            { _open 'https://www.openevidence.com/'; }
function keepa()         { _open 'https://keepa.com/#!'; }
function asc()           { _open 'https://sellercentral.amazon.co.jp/home'; }

# Load API keys from ~/.secrets into environment variables
function load_secret_environment() {
    if [ -f "$HOME/.secrets" ]; then
        set -a
        # shellcheck disable=SC1091
        source "$HOME/.secrets"
        set +a
    fi
}

# Re-sync API keys from Bitwarden and reload them
function sync_api_keys() {
    local script="$HOME/workspace/My_init_setting/ubuntu/installer/initialize_security.sh"
    if [ -f "$script" ]; then
        bash "$script"
        load_secret_environment
        echo "API keys synchronized successfully."
    else
        echo "Error: $script not found" >&2
    fi
}

load_secret_environment

# === WSL Aliases v2 ===

# Windows user home path (for WSL interop)
WIN_HOME=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')" 2>/dev/null || echo "/mnt/c/Users/lesen")

function qq()     { _open 'https://www.e-igakukai.jp/user_service/kaiin_portal/home/home.htm'; }

function claude() {
    read -rp "これはホスト環境です。実行しますか？(y/n): " response
    [[ "$response" =~ ^[Yy]$ ]] && command claude "$@"
}

function sbxcc() { sbx run claude "$@"; }
EOF

echo "Aliases configured in $BASHRC"
echo "Please restart your shell to apply changes."
