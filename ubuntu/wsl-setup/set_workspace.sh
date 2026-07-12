#!/bin/bash
set -e

WORKSPACE="$HOME/workspace"
BASHRC="$HOME/.bashrc"

mkdir -p "$WORKSPACE"
echo "Workspace directory: $WORKSPACE"

if ! grep -qF 'workspace="$HOME/workspace"' "$BASHRC"; then
    printf '\nworkspace="$HOME/workspace"\n' >> "$BASHRC"
    echo "Added \$workspace to $BASHRC"
fi

if ! grep -qF 'cd "$HOME/workspace"' "$BASHRC"; then
    printf 'cd "$HOME/workspace"\n' >> "$BASHRC"
    echo "Added startup cd to $BASHRC"
fi

echo "Please restart your shell to apply changes."
