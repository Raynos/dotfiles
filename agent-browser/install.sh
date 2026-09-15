#!/usr/bin/env bash
#
# Install Vercel's agent-browser (browser automation CLI for agents: Chrome via CDP, `-p ios` drives
# iOS simulators, `skills get core` for usage) as a user-level pnpm global — never npm -g, which
# installs per node version and vanishes on every nvm upgrade (claude/CLAUDE.md).
#
# Idempotent: pnpm add -g is a no-op at the pinned version; `agent-browser install` skips a present Chrome.
# Update procedure: bump AB_VERSION, re-run ./install.sh.
#
# Usage: ./install.sh
set -euo pipefail

AB_VERSION="0.37.1"

if command -v agent-browser >/dev/null && [ "$(agent-browser --version 2>/dev/null | awk '{print $2}')" = "$AB_VERSION" ]; then
  echo "ok    agent-browser $AB_VERSION"
else
  pnpm add -g "agent-browser@$AB_VERSION"
  echo "link  agent-browser $AB_VERSION -> ~/Library/pnpm"
fi
agent-browser install >/dev/null 2>&1 && echo "ok    chrome for agent-browser" || echo "warn: agent-browser install (chrome) failed — run it by hand"
echo "Done."
