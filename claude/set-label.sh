#!/bin/bash
# Set THIS session's status-line label + herdr agents-panel tag.
# Usage:  ~/.claude/set-label.sh "<=50 char goal, PR-title style>" "<=12 char tag>"
#   arg 1 (required): the status-line goal — QUOTE it (it's one argument now).
#   arg 2 (required): a short tag for the herdr agents panel. Mandatory so every
#                     goal update also refreshes the herdr row; capped at 12 chars
#                     (the widest that renders without clipping at the sidebar).
# Keyed by $CLAUDE_CODE_SESSION_ID, so every concurrent session has its own label.
[ -n "$CLAUDE_CODE_SESSION_ID" ] || { echo "no CLAUDE_CODE_SESSION_ID" >&2; exit 0; }
if [ "$#" -lt 2 ] || [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo 'usage: set-label.sh "<goal>" "<herdr-tag, <=12 chars>"  (both required)' >&2
  exit 2
fi
dir="$HOME/.claude/session-labels"
mkdir -p "$dir"
label=$(printf '%s' "$1" | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//' | cut -c1-50)
printf '%s' "$label" > "$dir/$CLAUDE_CODE_SESSION_ID.label"

# Mirror the short tag into the herdr agents panel (custom_status). No-op outside
# herdr. The panel truncates + doesn't wrap, so this is a terse tag, not a status
# line — 12 chars is the measured no-clip width (2026-07-04).
if [ "${HERDR_ENV:-}" = "1" ] && [ -n "${HERDR_PANE_ID:-}" ] && command -v herdr >/dev/null 2>&1; then
  tag=$(printf '%s' "$2" | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//' | cut -c1-12)
  herdr pane report-metadata "$HERDR_PANE_ID" --source claude:goal \
    --custom-status "$tag" >/dev/null 2>&1 || true
fi
