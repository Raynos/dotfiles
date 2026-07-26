#!/usr/bin/env bash

# Install curated Codex files without overwriting Codex runtime state.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="$HOME/.codex"
BACKUP_DIR="$CODEX_DIR/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"
ITEMS=(AGENTS.md hooks.json)

link_one() {
  local item="$1"
  local src="$REPO_DIR/$item"
  local dst="$CODEX_DIR/$item"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok    $item"
    return
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dst" "$BACKUP_DIR/$item"
    echo "backup $item"
  fi

  ln -s "$src" "$dst"
  echo "link   $item"
}

mkdir -p "$CODEX_DIR"
for item in "${ITEMS[@]}"; do
  link_one "$item"
done

node "$REPO_DIR/scripts/apply-managed-config.mjs" "$CODEX_DIR/config.toml"
node "$REPO_DIR/../agent-common/sync-agent-tooling.mjs" install
