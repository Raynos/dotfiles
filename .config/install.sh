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
# Link individual FILES, never whole app dirs. herdr-app (the Herdr desktop
# app) keeps a split: only what's ours is linked. Its own files there (AGENTS.md, *.d.ts, the shipped layouts/ and mods/,
# frame/, icons/, data/, shared.json, view.json, layouts/.state/) are rewritten by
# the app on every start and stay local. Personal layouts and mods are ours.
# settings.json stays local as well: the app saves the window zoom into it on
# every zoom in / out, which showed up here as a change each time, and the rest
# of it was defaults.
# keys.json is written by the app's Settings screen too. That is safe: herdr-app
# resolves the link and renames its temp file over the TARGET, so the symlink
# stays and the write lands in the repo. Verified 2026-11-19 on herdr-app 0.1.16
# with settings.json, which was linked then (`herdr-app do app.zoom_in` changed
# the repo file; its inode changed, the link didn't). Re-verify after a major
# upgrade.
# A mod linked as a folder doesn't hot-reload when its files change (upstream
# space-folders README). Re-creating its link reloads it with no restart
# (verified 2026-11-19 on herdr-app 0.1.16):
#   rm ~/.config/herdr-app/mods/<name> && ./.config/install.sh
ITEMS=(
  herdr-app/AGENTS.local.md
  herdr-app/keys.json
  herdr-app/layouts/main-folders.json
  herdr-app/mods/space-folders
  herdr-app/mods/github
  herdr-app/mods/github-button
  herdr-app/mods/two-pane-spaces
  herdr-app/mods/sessions
  herdr-app/mods/session-agents
  herdr-app/mods/session-picker
  herdr-app/themes/vibe.json
  herdr-app/themes/house.json
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

# herdr-app: make main-folders the shown layout. The app remembers the shown
# layout as "layout" in its own shared.json, which it reset to "main" on the
# 2026-11-22 update, so set it on every install. With the window open, switch
# it live; otherwise merge the key into shared.json for the next start.
HERDR_APP_LAYOUT=main-folders
if command -v herdr-app >/dev/null; then
  if herdr-app status >/dev/null 2>&1; then
    herdr-app do layout.switch --name "$HERDR_APP_LAYOUT" >/dev/null \
      && echo "herdr-app: layout -> $HERDR_APP_LAYOUT" \
      || echo "herdr-app: layout switch failed"
  else
    python3 - "$CONFIG_DIR/herdr-app/shared.json" "$HERDR_APP_LAYOUT" <<'PY'
import json, os, sys
path, layout = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
data["layout"] = layout
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f)
print(f"herdr-app: layout -> {layout} (applies on next start)")
PY
  fi
fi

# herdr-app: keep it on that one layout. A launchd agent runs
# herdr-app-pin-layout.sh when shared.json changes (a restart, the palette,
# another agent switching layouts) and every 30s, and switches back.
# Remove: launchctl bootout gui/$(id -u)/dev.dotfiles.herdr-app-layout
if [ "$(uname)" = "Darwin" ]; then
  PIN_LABEL=dev.dotfiles.herdr-app-layout
  PIN_PLIST="$HOME/Library/LaunchAgents/$PIN_LABEL.plist"
  PIN_TMP="$(mktemp)"
  cat >"$PIN_TMP" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$PIN_LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$REPO_DIR/herdr-app-pin-layout.sh</string></array>
  <key>WatchPaths</key>
  <array><string>$CONFIG_DIR/herdr-app/shared.json</string></array>
  <key>StartInterval</key><integer>30</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/herdr-app-pin-layout.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/herdr-app-pin-layout.log</string>
</dict>
</plist>
PLIST
  mkdir -p "$(dirname "$PIN_PLIST")"
  if cmp -s "$PIN_TMP" "$PIN_PLIST" && launchctl print "gui/$(id -u)/$PIN_LABEL" >/dev/null 2>&1; then
    rm -f "$PIN_TMP"
    echo "ok    launchd $PIN_LABEL"
  else
    launchctl bootout "gui/$(id -u)/$PIN_LABEL" >/dev/null 2>&1 || true
    mv "$PIN_TMP" "$PIN_PLIST"
    launchctl bootstrap "gui/$(id -u)" "$PIN_PLIST"
    echo "load  launchd $PIN_LABEL"
  fi
fi

echo "Done."
