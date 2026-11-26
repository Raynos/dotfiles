#!/bin/bash
# Bring the Tailscale VPN up without the Tailscale app window.
# The App Store app runs the tunnel in its IPNExtension; macOS's own VPN
# control (scutil --nc) can start it with the app closed. Quitting the app
# stops the tunnel, so the launchd agent runs this at login and every 60s.
name=Tailscale
status="$(scutil --nc status "$name" 2>/dev/null | head -1)"
case "$status" in
  Connected|Connecting) exit 0 ;;
  "") echo "$(date '+%F %T') no VPN service named $name"; exit 0 ;;
esac
echo "$(date '+%F %T') $status -> start"
scutil --nc start "$name"
