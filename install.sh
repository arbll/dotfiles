#!/bin/bash
# Bootstrap chezmoi on a workspace
# This script is called by the workspaces dotfiles system during creation.
# When install.sh exists, no automatic symlinking occurs — we handle everything via chezmoi.

set -euo pipefail

LOGFILE="$HOME/.dotfiles-install.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "=== dotfiles install started at $(date) ==="

echo "=== debug: git config ==="
git config --global --list --show-origin 2>&1 || true
echo "=== debug: git config (system) ==="
git config --system --list --show-origin 2>&1 || true
echo "=== debug: env ==="
env | grep -iE '(GIT|SSH|HOME|USER|PATH|SUDO)' | sort || true
echo "=== debug: ssh test ==="
ssh -T git@github.com 2>&1 || true
echo "=== debug: which git / sudo ==="
which git sudo 2>&1 || true
echo "=== debug: sudo git config ==="
sudo git config --global --list --show-origin 2>&1 || true
echo "=== end debug ==="

# # Install chezmoi if not already present
# if ! command -v chezmoi &>/dev/null; then
#     sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
#     export PATH="$HOME/.local/bin:$PATH"
# fi
#
# # Initialize and apply dotfiles from this repo (already cloned by workspaces)
# # The workspaces system clones the dotfiles repo, so we can init from the local copy.
# SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# chezmoi init --source="$SCRIPT_DIR" --apply -v

echo "=== dotfiles install finished at $(date) ==="
