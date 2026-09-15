#!/usr/bin/env bash
#
# Install Vercel's agent-browser (browser automation CLI for agents: Chrome via CDP, `-p ios` drives
# iOS simulators, `skills get core` for usage) as a user-level pnpm global — never npm -g, which
# installs per node version and vanishes on every nvm upgrade (claude/CLAUDE.md).
#
# Idempotent: install only when the pinned version is missing, then link managed files.
# Update procedure: bump version, refresh the upstream skill, re-run ./install.sh.
#
# Usage: ./install.sh
set -euo pipefail

AB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AB_REPO="$(dirname "$AB_DIR")"
AB_VERSION="$(cat "$AB_DIR/version")"
AB_BACKUP="$HOME/.agent-browser/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

if command -v agent-browser >/dev/null && [ "$(agent-browser --version 2>/dev/null | awk '{print $2}')" = "$AB_VERSION" ]; then
  echo "ok    agent-browser $AB_VERSION"
else
  pnpm add -g "agent-browser@$AB_VERSION"
  echo "link  agent-browser $AB_VERSION -> ~/Library/pnpm"
fi
agent-browser install

link_managed() {
  local src="$1" dst="$2" backup_name="$3"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok    ${dst#$HOME/}"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$AB_BACKUP"
    mv "$dst" "$AB_BACKUP/$backup_name"
    echo "backup ${dst#$HOME/} -> ${AB_BACKUP#$HOME/}/$backup_name"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "link  ${dst#$HOME/} -> ${src#$HOME/}"
}

link_managed "$AB_DIR/config.json" "$HOME/.agent-browser/config.json" config.json
link_managed "$AB_REPO/agents/skills/agent-browser" "$HOME/.agents/skills/agent-browser" agents-skill
link_managed "$AB_REPO/agents/skills/agent-browser" "$HOME/.claude/skills/agent-browser" claude-skill
echo "Done."
