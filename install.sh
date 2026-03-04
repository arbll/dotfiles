#!/bin/bash
# Bootstrap chezmoi on a workspace
# This script is called by the workspaces dotfiles system during creation.
# When install.sh exists, no automatic symlinking occurs — we handle everything via chezmoi.

set -euo pipefail

# Prevent concurrent runs (workspaces may retry install.sh while it's still running)
LOCKFILE="$HOME/.dotfiles-install.lock"
if [ -f "$LOCKFILE" ]; then
    echo "install.sh already running (lockfile exists), skipping."
    exit 0
fi
touch "$LOCKFILE"

RESTORED_SSH_REWRITE=false
cleanup() {
    rm -f "$LOCKFILE"
    if [ "$RESTORED_SSH_REWRITE" = false ] && [ -n "${SSH_REWRITE_VALUE:-}" ]; then
        git config --global url."git@github.com:".insteadOf "$SSH_REWRITE_VALUE"
    fi
}
trap cleanup EXIT

LOGFILE="$HOME/.dotfiles-install.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "=== dotfiles install started at $(date) ==="

# SSH agent forwarding is not available during workspace creation.
# The workspace .gitconfig rewrites HTTPS to SSH, which breaks cloning
# public repos (Homebrew, etc). Temporarily remove the rewrite.
SSH_REWRITE_VALUE=$(git config --global --get url."git@github.com:".insteadOf 2>/dev/null || true)
if [ -n "$SSH_REWRITE_VALUE" ]; then
    echo "Temporarily removing git SSH rewrite for install..."
    git config --global --unset url."git@github.com:".insteadOf
fi

# Install chezmoi if not already present
if ! command -v chezmoi &>/dev/null; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
fi

# Initialize and apply dotfiles from this repo (already cloned by workspaces)
# The workspaces system clones the dotfiles repo, so we can init from the local copy.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
chezmoi init --source="$SCRIPT_DIR" --apply -v

# Restore SSH rewrite (also handled by trap in case of failure)
if [ -n "$SSH_REWRITE_VALUE" ]; then
    git config --global url."git@github.com:".insteadOf "$SSH_REWRITE_VALUE"
    RESTORED_SSH_REWRITE=true
fi

echo "=== dotfiles install finished at $(date) ==="
