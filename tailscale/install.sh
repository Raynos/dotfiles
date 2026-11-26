#!/usr/bin/env bash
#
# Keep the Tailscale VPN up at login without the Tailscale app window.
# A launchd agent runs vpn-up.sh at login and every 60s; it starts the
# App Store app's VPN with scutil when it is not connected.
#
# Usage: ./tailscale/install.sh
# Remove: launchctl bootout gui/$(id -u)/dev.dotfiles.tailscale-up
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(uname)" != "Darwin" ]; then
  echo "skip  tailscale: macOS only"
  exit 0
fi

LABEL=dev.dotfiles.tailscale-up
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
TMP="$(mktemp)"
cat >"$TMP" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$REPO_DIR/vpn-up.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>60</integer>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/tailscale-up.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/tailscale-up.log</string>
</dict>
</plist>
PLIST
mkdir -p "$(dirname "$PLIST")"
if cmp -s "$TMP" "$PLIST" && launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  rm -f "$TMP"
  echo "ok    launchd $LABEL"
else
  launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
  mv "$TMP" "$PLIST"
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "load  launchd $LABEL"
fi
