#!/bin/bash
# Custom SessionStart hook (lives beside the herdr-managed herdr-agent-state.sh,
# per its "add custom hooks beside this file" note).
#
# Why: set-label.sh mirrors a short tag into the herdr agents panel via
# `herdr pane report-metadata --token goal=<tag>`. That metadata is keyed by PANE,
# not session — so a tag set last session (e.g. "f6-fixtures") lingers as a
# stale, misleading chip when a fresh session starts in the same pane.
#
# Fix: on a FRESH session (source=startup|clear) clear the pane's `goal` token.
# On resume/compact the conversation continues, so the tag is still accurate —
# leave it alone.
#
# herdr 0.7.x removed `--clear-custom-status`; the token equivalent is
# `--clear-token goal`. Keep this flag in sync with set-label.sh's `--token`.

set -eu

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0

input=$(cat 2>/dev/null || true)
# Extract "source" from the hook JSON without depending on jq.
src=$(printf '%s' "$input" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

case "$src" in
  startup|clear|"")
    herdr pane report-metadata "$HERDR_PANE_ID" --source claude:goal \
      --clear-token goal >/dev/null 2>&1 || true
    ;;
esac
exit 0
