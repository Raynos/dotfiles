#!/usr/bin/env bash
#
# Symlink this repo's curated cross-agent skills into ~/.agents.
#
# The repo holds the REAL files; ~/.agents gets symlinks pointing back here,
# so edits made live in ~/.agents flow straight into git. Note skills/herdr
# in this directory is itself a repo-internal symlink to ../claude/skills/herdr
# — the single source of truth — so .agents-only harnesses see the same,
# current herdr skill with zero duplication.
#
# Idempotent: re-run any time. An existing real file/dir at a target path is
# moved into a timestamped backup under ~/.agents/ before the symlink is made.
#
# Usage: ./install.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$HOME/.agents"
BACKUP_DIR="$AGENTS_DIR/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

# Curated items, path-relative to BOTH the repo dir and ~/.agents.
ITEMS=(
  skills/find-skills
  skills/herdr
)

link_one() {
  local item="$1"
  local src="$REPO_DIR/$item"
  local dst="$AGENTS_DIR/$item"

  if [ ! -e "$src" ]; then
    echo "skip (missing in repo): $item"
    return
  fi

  # Already the correct symlink? Nothing to do.
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok    $item"
    return
  fi

  # Back up whatever is currently there (real file/dir or stale symlink).
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$item")"
    mv "$dst" "$BACKUP_DIR/$item"
    echo "backup $item -> ${BACKUP_DIR#$HOME/}/$item"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "link   $item -> ${src#$HOME/}"
}

echo "Linking cross-agent skills into $AGENTS_DIR"
mkdir -p "$AGENTS_DIR"
for item in "${ITEMS[@]}"; do
  link_one "$item"
done

echo "Done."
