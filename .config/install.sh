#!/usr/bin/env bash
#
# Symlink this repo's curated ~/.config files into place.
#
# Same contract as claude/install.sh: the repo holds the REAL files, ~/.config
# gets symlinks pointing back here, so edits made live (including ones the app
# itself writes) flow straight into git instead of drifting.
#
# Idempotent: re-run any time. An existing real file at a target path is moved
# into a timestamped backup under ~/.config/ before the symlink is made.
#
# Usage: ./.config/install.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$CONFIG_DIR/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

# Curated items, path-relative to BOTH this dir and ~/.config.
#
# Link individual FILES, never whole app dirs. ~/.config/herdr also holds pure
# runtime state — herdr.sock, herdr-server.log, sessions/, plugins/ — that must
# stay local to the machine and out of git.
#
# Symlinking config.toml is safe because herdr rewrites it IN PLACE rather than
# via the atomic rename-into-place that would replace the symlink with a real
# file. Verified 2026-07-26 on herdr 0.7.5: with the symlink installed, a real
# config write (`herdr config reset-keys` removing a [keys] block) followed the
# link and landed in the repo file, inode unchanged. This is exactly the failure
# mode that forced claude/settings.json out of claude/install.sh, so re-verify
# after a major herdr upgrade:
#
#   ls -la ~/.config/herdr/config.toml   # still a symlink?
#
ITEMS=(
  herdr/config.toml
  herdr/herdr-cwd-labels.sh
)

link_one() {
  local item="$1"
  local src="$REPO_DIR/$item"
  local dst="$CONFIG_DIR/$item"

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

echo "Linking config into $CONFIG_DIR"
for item in "${ITEMS[@]}"; do
  link_one "$item"
done

# herdr reads config.toml at startup; a running server needs a nudge to pick up
# a freshly linked file. Harmless when no server is running.
if command -v herdr >/dev/null; then
  echo ""
  herdr config check || true
  herdr server reload-config >/dev/null 2>&1 \
    && echo "herdr: reloaded running server" \
    || echo "herdr: no running server to reload (config applies on next start)"
fi

echo "Done."
