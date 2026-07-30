#!/usr/bin/env bash
#
# Install this repo's pnpm global rc into pnpm's globalconfig path.
#
# On macOS that is ~/Library/Preferences/pnpm/rc; on Linux
# ~/.config/pnpm/rc (or $XDG_CONFIG_HOME/pnpm/rc). Kept out of ~/.npmrc
# so registry auth tokens there are never overwritten by bootstrap.
#
# Idempotent: re-run any time.
#
# Usage: ./pnpm/install.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/rc"

if [ ! -f "$SRC" ]; then
  echo "missing: $SRC" >&2
  exit 1
fi

if command -v pnpm >/dev/null; then
  DST="$(pnpm config get globalconfig)"
else
  case "$(uname -s)" in
    Darwin)
      DST="$HOME/Library/Preferences/pnpm/rc"
      ;;
    *)
      DST="${XDG_CONFIG_HOME:-$HOME/.config}/pnpm/rc"
      ;;
  esac
fi

BACKUP_DIR="$HOME/.pnpm-dotfiles-backup-$(date +%Y%m%d%H%M%S)"

if [ -L "$DST" ] && [ "$(readlink "$DST")" = "$SRC" ]; then
  echo "ok    ${DST#$HOME/}"
  exit 0
fi

if [ -e "$DST" ] || [ -L "$DST" ]; then
  mkdir -p "$BACKUP_DIR"
  mv "$DST" "$BACKUP_DIR/rc"
  echo "backup ${DST#$HOME/} -> ${BACKUP_DIR#$HOME/}/rc"
fi

mkdir -p "$(dirname "$DST")"
ln -s "$SRC" "$DST"
echo "link   ${DST#$HOME/} -> ${SRC#$HOME/}"

if command -v pnpm >/dev/null; then
  echo "enable-global-virtual-store=$(pnpm config get enable-global-virtual-store)"
fi

echo "Done."
