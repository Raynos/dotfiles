#!/usr/bin/env bash
#
# Install ChmaraX/herdr-gitview into the Herdr desktop app, pinned to ./version.
# gitview takes over the layout's Changes panel (git status, diffs, stage,
# discard, commit, review notes for an agent); cmd-shift-g shows or hides it.
#
# Its mods carry a prebuilt binary, and its own installer swaps them in by
# rename on every upgrade, so they're NOT tracked here: they live as real
# folders in ~/.config/herdr-app/mods/gitview*. What it changes outside them is
# tracked here already: the layout's `changes` block
# (.config/herdr-app/layouts/main-folders.json) and cmd-shift-g in keys.json.
#
# That installer saves the layout and keys.json by renaming a temp file over
# them, which turns the .config/install.sh symlinks into real files. With the
# repo files already patched it has nothing to write there. If it ever does:
# copy the real file over the repo one, then re-run .config/install.sh.
#
# Idempotent: installs only when the pinned version isn't the one recorded in
# mods/gitview/.dotfiles-version (a hidden file, which gitview's installer
# leaves alone). Needs the Herdr app running. Update: bump version, re-run.
#
# Usage: ./herdr-gitview/install.sh
set -euo pipefail

GV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GV_VERSION="$(cat "$GV_DIR/version")"
APP_HOME="${HERDR_APP_HOME:-$HOME/.config/herdr-app}"
MARK="$APP_HOME/mods/gitview/.dotfiles-version"

if [ -f "$MARK" ] && [ "$(cat "$MARK")" = "$GV_VERSION" ] && [ -x "$APP_HOME/mods/gitview/bin/herdr-gitview" ]; then
  echo "ok    herdr-gitview $GV_VERSION"
  exit 0
fi
if ! command -v herdr-app >/dev/null || ! herdr-app status >/dev/null 2>&1; then
  echo "skip  herdr-gitview: start the Herdr app first, then re-run $0"
  exit 0
fi

# The installer from the same tag, so script and bundle match. It checks the
# bundle against the release's .sha256: integrity, not authenticity.
curl -fsSL "https://raw.githubusercontent.com/ChmaraX/herdr-gitview/$GV_VERSION/install.sh" \
  | sh -s -- --app --version "$GV_VERSION"
printf '%s\n' "$GV_VERSION" > "$MARK"
echo "Done."
