#!/data/data/com.termux/files/usr/bin/bash
# set_workspace.sh - Setup workspace directory and update profile
set -e

WORKSPACE_DIR="$HOME/workspace"

# Create workspace directory if it doesn't exist
if [ ! -d "$WORKSPACE_DIR" ]; then
    mkdir -p "$WORKSPACE_DIR"
    echo "Workspace directory created at $WORKSPACE_DIR"
else
    echo "Workspace directory already exists at $WORKSPACE_DIR"
fi

# Update .bash_profile
BASH_PROFILE="$HOME/.bash_profile"
WORKSPACE_LINE="export WORKSPACE=\"\$HOME/workspace\""

if ! grep -q "export WORKSPACE=" "$BASH_PROFILE" 2>/dev/null; then
    echo -e "\n# Workspace path\n$WORKSPACE_LINE" >> "$BASH_PROFILE"
    echo "Workspace path added to .bash_profile"
fi

echo "Workspace setup complete."
