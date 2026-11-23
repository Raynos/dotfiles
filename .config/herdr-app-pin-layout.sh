#!/usr/bin/env bash
#
# Keep the Herdr app on one layout: main-folders.
#
# Herdr rewrites its own layouts (main, terminals, win98) on every start, so
# they can't be deleted, and it has no "start on this layout" setting: after a
# restart it can come back on main. This runs from the launchd agent that
# .config/install.sh writes (dev.dotfiles.herdr-app-layout), whenever the app's
# shared.json changes and every 30 seconds, and switches the open window back.
#
# Does nothing when the window isn't open or is already on the layout.
set -u
PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin"

WANT=main-folders
SHARED="${XDG_CONFIG_HOME:-$HOME/.config}/herdr-app/shared.json"

cur="$(plutil -extract layout raw -o - "$SHARED" 2>/dev/null)" || cur=""
[ "$cur" = "$WANT" ] && exit 0

command -v herdr-app >/dev/null || exit 0
herdr-app status >/dev/null 2>&1 || exit 0 # no window open; status never opens one

herdr-app do layout.switch --name "$WANT" >/dev/null 2>&1 \
  && echo "$(date '+%F %T') herdr-app layout ${cur:-?} -> $WANT"
exit 0
