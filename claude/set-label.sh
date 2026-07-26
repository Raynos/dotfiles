#!/bin/bash
# Set THIS session's status-line label + herdr agents-panel tag.
# Usage:  ~/.claude/set-label.sh "<=50 char goal, PR-title style>" "<=24 char tag>"
#   arg 1 (required): the status-line goal — QUOTE it (it's one argument now).
#   arg 2 (required): a short tag for the herdr agents panel. Mandatory so every
#                     goal update also refreshes the herdr row; capped at 24 chars
#                     (the widest that renders without clipping at the sidebar).
# Keyed by $CLAUDE_CODE_SESSION_ID, so every concurrent session has its own label.
[ -n "$CLAUDE_CODE_SESSION_ID" ] || { echo "no CLAUDE_CODE_SESSION_ID" >&2; exit 0; }
if [ "$#" -lt 2 ] || [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo 'usage: set-label.sh "<goal>" "<herdr-tag, <=24 chars>"  (both required)' >&2
  exit 2
fi
dir="$HOME/.claude/session-labels"
mkdir -p "$dir"
label=$(printf '%s' "$1" | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//' | cut -c1-50)
printf '%s' "$label" > "$dir/$CLAUDE_CODE_SESSION_ID.label"

# Mirror the tag into the herdr agents panel. No-op outside herdr. The panel
# truncates + doesn't wrap, so this is still a phrase, not a sentence — 24 chars is
# the measured no-clip width (2026-07-26), up from 12 now that `$goal` owns a full
# sidebar row instead of sharing one with the harness name, and the sidebar floor
# is pinned at 30 columns. That cap is a function of BOTH facts: re-measure it if
# either the row layout or sidebar_min_width in config.toml changes.
#
# herdr 0.7.x REMOVED `--custom-status`; display-only pane metadata is now a token
# map, and the sidebar renders a token as `$name` only if config.toml asks it to.
# So this writes token `goal`, and dotfiles/.config/herdr/config.toml carries the
# matching `[ui.sidebar.agents]` row referencing `$goal`. BOTH halves are required —
# writing the token alone renders nothing. (re-verified against herdr 0.7.5)
if [ "${HERDR_ENV:-}" = "1" ] && [ -n "${HERDR_PANE_ID:-}" ] && command -v herdr >/dev/null 2>&1; then
  tag=$(printf '%s' "$2" | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//' | cut -c1-24)
  herdr pane report-metadata "$HERDR_PANE_ID" --source claude:goal \
    --token "goal=$tag" >/dev/null 2>&1 || true
fi
