#!/usr/bin/env bash

# Apply curated Grok config without overwriting Grok runtime state.
#
# The repo owns two things here: the managed subset of config.toml (merged,
# not linked — see scripts/apply-managed-config.mjs) and hooks/dcg.json, which
# Grok auto-discovers from ~/.grok/hooks/*.json at session start. Everything
# else in ~/.grok (README.md, docs/, bundled/) is vendor-shipped and replaced
# on update, so it is deliberately not managed.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROK_DIR="${GROK_HOME:-$HOME/.grok}"
BACKUP_DIR="$GROK_DIR/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

# Curated items, path-relative to BOTH the repo dir and ~/.grok.
ITEMS=(
  hooks/dcg.json
)

link_one() {
  local item="$1"
  local src="$REPO_DIR/$item"
  local dst="$GROK_DIR/$item"

  # Already the correct symlink? Nothing to do.
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok    $item"
    return
  fi

  # Back up whatever is currently there (real file or stale symlink).
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$item")"
    mv "$dst" "$BACKUP_DIR/$item"
    echo "backup $item -> ${BACKUP_DIR#"$HOME"/}/$item"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "link   $item -> ${src#"$HOME"/}"
}

mkdir -p "$GROK_DIR"
for item in "${ITEMS[@]}"; do
  link_one "$item"
done

node "$REPO_DIR/scripts/apply-managed-config.mjs" "$GROK_DIR/config.toml"
