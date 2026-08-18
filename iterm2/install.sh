#!/usr/bin/env bash
#
# Point iTerm2 at this repo's versioned preferences.
#
# Uses iTerm2's official "load settings from a custom folder" mechanism:
# iTerm2 reads com.googlecode.iterm2.plist from THIS directory at launch and
# writes changes back here (per its "Save changes" setting), so profile and
# settings edits made in the iTerm2 UI flow straight into git — same
# philosophy as the symlink installers, via iTerm2's supported path (iTerm2
# rewrites its plist wholesale, so a symlink would not survive).
#
# The plist is the full settings file: profiles (Default / Vibe / House —
# bin/herdr-attach depends on those names), global key maps, pointer actions,
# and appearance. Machine noise (window frames, updater state, NoSync* keys)
# was stripped at export time and iTerm2 does not write NoSync* keys to
# custom folders.
#
# Idempotent: re-run any time. Restart iTerm2 to pick up changes.
#
# Usage: ./install.sh
#
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "skip: iterm2/install.sh targets macOS only"
  exit 0
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN="com.googlecode.iterm2"

current_folder="$(defaults read "$DOMAIN" PrefsCustomFolder 2>/dev/null || true)"
current_load="$(defaults read "$DOMAIN" LoadPrefsFromCustomFolder 2>/dev/null || true)"

if [ "$current_folder" = "$REPO_DIR" ] && [ "$current_load" = "1" ]; then
  echo "ok    iTerm2 already loads settings from ${REPO_DIR#$HOME/}"
else
  defaults write "$DOMAIN" PrefsCustomFolder -string "$REPO_DIR"
  defaults write "$DOMAIN" LoadPrefsFromCustomFolder -bool true
  echo "set   iTerm2 custom settings folder -> ${REPO_DIR#$HOME/}"
  echo "note: restart iTerm2 to load them"
fi

# "Save changes" = Automatically (Settings > General > Settings). Without this
# the whole versioned-plist flow silently no-ops — iTerm2 never writes UI edits
# back into the repo. NoSync* keys live in the local plist, never in the custom
# folder, so the GUI toggle can't be captured by the versioned file itself.
current_save="$(defaults read "$DOMAIN" NoSyncNeverRemindPrefsChangesLostForFile_selection 2>/dev/null || true)"
if [ "$current_save" = "2" ]; then
  echo "ok    iTerm2 'Save changes' already set to Automatically"
else
  defaults write "$DOMAIN" NoSyncNeverRemindPrefsChangesLostForFile -bool true
  defaults write "$DOMAIN" NoSyncNeverRemindPrefsChangesLostForFile_selection -int 2
  echo "set   iTerm2 'Save changes' -> Automatically (takes effect on restart)"
fi

echo "Done."
