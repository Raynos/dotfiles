#!/usr/bin/env bash
#
# Symlink this repo's Cursor user config into Cursor's User dir and sync
# extensions from extensions.txt.
#
# The repo holds the REAL files; Cursor's User dir gets symlinks pointing back
# here, so edits made live in Cursor's settings UI flow straight into git —
# nothing drifts or gets lost. Everything else in the User dir (globalStorage,
# workspaceStorage, history) is never touched.
#
# NOTE: if Cursor's atomic saves ever replace the symlink with a real file
# (the way Claude Code does to settings.json — see claude/install.sh), switch
# to the key-merge approach in claude/scripts/apply-managed-settings.mjs.
#
# Idempotent: re-run any time. An existing real file at a target path is moved
# into a timestamped backup before the symlink is made.
#
# Usage: ./install.sh
#
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "skip: cursor/install.sh targets macOS paths only"
  exit 0
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
BACKUP_DIR="$CURSOR_USER_DIR/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

# Curated items, path-relative to BOTH the repo dir and Cursor's User dir.
ITEMS=(
  settings.json
  keybindings.json
)

link_one() {
  local item="$1"
  local src="$REPO_DIR/$item"
  local dst="$CURSOR_USER_DIR/$item"

  if [ ! -e "$src" ]; then
    echo "skip (missing in repo): $item"
    return
  fi

  # Already the correct symlink? Nothing to do.
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok    $item"
    return
  fi

  # Back up whatever is currently there (real file or stale symlink).
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$item")"
    mv "$dst" "$BACKUP_DIR/$item"
    echo "backup $item -> ${BACKUP_DIR#$HOME/}/$item"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "link   $item -> ${src#$HOME/}"
}

echo "Linking Cursor user config into $CURSOR_USER_DIR"
mkdir -p "$CURSOR_USER_DIR"
for item in "${ITEMS[@]}"; do
  link_one "$item"
done

# Install extensions declaratively from extensions.txt (VS Code-extensions
# style, same pattern as claude/plugins.json).
if command -v cursor >/dev/null; then
  echo ""
  echo "Syncing extensions from extensions.txt"
  installed="$(cursor --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  while IFS= read -r ext; do
    [ -z "$ext" ] && continue
    case "$ext" in '#'*) continue ;; esac
    if printf '%s\n' "$installed" | grep -qix "$ext"; then
      echo "ok    $ext"
    else
      echo "install $ext"
      # Warn-and-continue: one extension missing from Cursor's marketplace
      # (e.g. not mirrored from VS Code's) must not abort the rest of the sync.
      cursor --install-extension "$ext" >/dev/null || \
        echo "warn: failed to install $ext — continuing"
    fi
  done < "$REPO_DIR/extensions.txt"
else
  echo ""
  echo "note: skipping extension sync (need 'cursor' CLI on PATH; open Cursor once, then re-run)"
fi

echo "Done."
