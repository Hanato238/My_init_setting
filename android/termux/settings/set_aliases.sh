#!/data/data/com.termux/files/usr/bin/bash
# set_aliases.sh - Update .bashrc and .bash_profile with aliases and sync command
set -e

BASHRC="$HOME/.bashrc"
BASH_PROFILE="$HOME/.bash_profile"

# Backup
[ -f "$BASHRC" ]      && cp "$BASHRC"      "${BASHRC}.bak"
[ -f "$BASH_PROFILE" ] && cp "$BASH_PROFILE" "${BASH_PROFILE}.bak"

# Create .bashrc
cat > "$BASHRC" << 'EOF'
# Aliases
alias la="ls -a"
alias ll="ls -l"
alias lf="ls -al"
alias gemini="gemini" # Standard command
EOF

# Create .bash_profile with Sync-ApiKeys function
cat > "$BASH_PROFILE" << 'EOF'
# Environment paths
export SCRIPTS="$HOME/storage/documents/termux/scripts"
export TERMUX="$HOME/storage/documents/termux"
export DOCUMENTS="$HOME/storage/documents"
export DOWNLOADS="$HOME/storage/downloads"
export WORKSPACE="$HOME/workspace"

# Load API keys from ~/.secrets
if [ -f "$HOME/.secrets" ]; then
    source "$HOME/.secrets"
fi

# Function to quickly sync Bitwarden updates
sync_api_keys() {
    echo "Fetching latest keys from Bitwarden..."
    local script_path="$HOME/workspace/My_init_setting/android/termux/installer/initialize_security.sh"
    if [ -f "$script_path" ]; then
        bash "$script_path"
        if [ -f "$HOME/.secrets" ]; then
            source "$HOME/.secrets"
            echo "API keys synchronized successfully."
        fi
    else
        echo "Error: Could not find $script_path"
    fi
}
EOF

echo "Done: .bashrc and .bash_profile have been updated with aliases and sync_api_keys function."
