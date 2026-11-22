#!/usr/bin/env bash
#
# Install sirmalloc/ccstatusline (Claude Code's status line renderer) as a user-level pnpm global,
# never npm -g, which installs per node version and vanishes on every nvm upgrade
# (bin/node-global-doctor), and link its config from this repo.
#
# claude/settings.managed.json points statusLine at `ccstatusline`. The first widget runs
# ~/.claude/statusline.sh, so the set-label.sh goal and the usage cache keep working.
#
# Idempotent: install only when the pinned version is missing, then link the config.
# Update procedure: bump version, re-run ./install.sh.
#
# Usage: ./install.sh
set -euo pipefail

CS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CS_VERSION="$(cat "$CS_DIR/version")"
CS_CONFIG="$HOME/.config/ccstatusline"
CS_BACKUP="$CS_CONFIG/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

if command -v ccstatusline >/dev/null && [ "$(ccstatusline --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)" = "$CS_VERSION" ]; then
  echo "ok    ccstatusline $CS_VERSION"
else
  pnpm add -g "ccstatusline@$CS_VERSION"
  echo "link  ccstatusline $CS_VERSION -> pnpm global bin"
fi

# ccstatusline saves through a symlink to its target (atomic write beside the real file),
# so edits made in its TUI land in this repo.
src="$CS_DIR/settings.json"
dst="$CS_CONFIG/settings.json"
if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
  echo "ok    ${dst#$HOME/}"
else
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$CS_BACKUP"
    mv "$dst" "$CS_BACKUP/settings.json"
    echo "backup ${dst#$HOME/} -> ${CS_BACKUP#$HOME/}/settings.json"
  fi
  mkdir -p "$CS_CONFIG"
  ln -s "$src" "$dst"
  echo "link  ${dst#$HOME/} -> ${src#$HOME/}"
fi
echo "Done."
