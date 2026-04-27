#!/data/data/com.termux/files/usr/bin/bash
set -e

BASHRC="$HOME/.bashrc"
BASH_PROFILE="$HOME/.bash_profile"

[ -f "$BASHRC" ]      && cp "$BASHRC"      "${BASHRC}.bak"
[ -f "$BASH_PROFILE" ] && cp "$BASH_PROFILE" "${BASH_PROFILE}.bak"

cat > "$BASHRC" << 'EOF'
alias la="ls -a"
alias ll="ls -l"
alias lf="ls -al"
EOF

cat > "$BASH_PROFILE" << 'EOF'
export SCRIPTS="$HOME/storage/documents/termux/scripts"
export TERMUX="$HOME/storage/documents/termux"
export DOCUMENTS="$HOME/storage/documents"
export DOWNLOADS="$HOME/storage/downloads"

# Load API keys from Bitwarden CLI
_bw_load_secrets() {
    # Reuse cached session token if still valid
    local session_file="$HOME/.bw_session"
    if [ -f "$session_file" ]; then
        export BW_SESSION=$(cat "$session_file")
    fi

    if ! bw status 2>/dev/null | grep -q '"status":"unlocked"'; then
        echo "[bw] Vault locked. Unlocking..."
        BW_SESSION=$(bw unlock --raw)
        echo "$BW_SESSION" > "$session_file"
        chmod 600 "$session_file"
        export BW_SESSION
    fi

    _bw_get() { bw get notes "$1" 2>/dev/null; }
    export PERPLEXITY_API_KEY=$(_bw_get "PERPLEXITY_API_KEY")
    export GITHUB_PERSONAL_ACCESS_TOKEN=$(_bw_get "GITHUB_PERSONAL_ACCESS_TOKEN")
    export HF_TOKEN=$(_bw_get "HF_TOKEN")
    export GOOGLE_CLIENT_ID=$(_bw_get "GOOGLE_CLIENT_ID")
    export GOOGLE_CLIENT_SECRET=$(_bw_get "GOOGLE_CLIENT_SECRET")
    unset -f _bw_get
}

if command -v bw &>/dev/null; then
    _bw_load_secrets
fi
unset -f _bw_load_secrets
EOF

echo "Done: .bashrc and .bash_profile have been overwritten."
echo "Run: source ~/.bash_profile"
