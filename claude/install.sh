#!/usr/bin/env bash
#
# Symlink this repo's curated Claude Code tooling into ~/.claude.
#
# The repo holds the REAL files; ~/.claude gets symlinks pointing back here,
# so edits made live in ~/.claude flow straight into git — nothing drifts or
# gets lost. Runtime state in ~/.claude (sessions, history, caches, .claude.json,
# installed plugins) is left untouched.
#
# Idempotent: re-run any time. An existing real file/dir at a target path is
# moved into a timestamped backup under ~/.claude/ before the symlink is made.
#
# Usage: ./install.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

# Curated items, path-relative to BOTH the repo dir and ~/.claude.
# Directories are symlinked whole; anything not listed here (runtime state) is
# never touched.
# NOTE: settings.json is deliberately NOT here. Claude Code rewrites it (model,
# plugins, notification channel), and an atomic write replaces a symlink instead
# of following it — it broke twice, see the .dotfiles-backup-* dirs. It is merged
# key-by-key instead, at the bottom of this script.
ITEMS=(
  CLAUDE.md
  set-label.sh
  session-label-remind.sh
  statusline.sh
  hooks
  skills/herdr
  sounds
)

link_one() {
  local item="$1"
  local src="$REPO_DIR/$item"
  local dst="$CLAUDE_DIR/$item"

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

echo "Linking Claude Code tooling into $CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR"
for item in "${ITEMS[@]}"; do
  link_one "$item"
done

# Merge the managed subset of settings.json in place, leaving app-owned keys
# (model, theme, enabledPlugins, ...) exactly as Claude Code left them.
if command -v node >/dev/null; then
  echo ""
  echo "Applying managed settings"
  node "$REPO_DIR/scripts/apply-managed-settings.mjs"
else
  echo ""
  echo "note: skipping managed settings (need 'node'); run scripts/apply-managed-settings.mjs later"
fi

# Reinstall plugins declaratively from plugins.json (VS Code-extensions style).
if command -v claude >/dev/null && command -v jq >/dev/null; then
  echo ""
  echo "Syncing plugins from plugins.json"
  "$REPO_DIR/sync-plugins.sh" install
else
  echo ""
  echo "note: skipping plugin sync (need 'claude' + 'jq'); run ./sync-plugins.sh install later"
fi

echo "Done."
