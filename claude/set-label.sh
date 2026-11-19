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
  # Keep the tab and workspace names in step with the goal (Jake, 2026-10-03: "the names of the panes and the
  # spaces, the tabs, they're all completely stale"). Only where this pane is alone: a tab with one pane takes the
  # tag; a workspace with one tab and one pane takes it too. A shared tab or workspace keeps its human-chosen name.
  herdr pane current --current 2>/dev/null | /usr/bin/python3 -c '
import json, subprocess, sys
tag = sys.argv[1]
try:
    pane = json.load(sys.stdin)["result"]["pane"]
    run = lambda *a: json.loads(subprocess.run(["herdr", *a], capture_output=True, text=True).stdout)["result"]
    tab = run("tab", "get", pane["tab_id"])["tab"]
    if tab.get("pane_count") == 1 and tab.get("label") != tag:
        subprocess.run(["herdr", "tab", "rename", tab["tab_id"], tag], capture_output=True)
        ws = run("workspace", "get", tab["workspace_id"])["workspace"]
        if ws.get("tab_count") == 1 and ws.get("pane_count") == 1 and ws.get("label") != tag:
            subprocess.run(["herdr", "workspace", "rename", ws["workspace_id"], tag], capture_output=True)
except Exception:
    pass
' "$tag" >/dev/null 2>&1 || true
fi

# The Herdr desktop app (herdr-app; terminals run in herdr-core, which sets
# $HC_TERMINAL_ID). Its tabs have no agents-panel token, but an unnamed tab is
# called by its number, and the app's Go-to picker (cmd-p) lists agents by tab
# name: every agent showed as "1" (Jake, 2026-11-19: "why are these things 1").
# So the tab takes the tag while its name is still a number (nobody named it) or
# is the tag this session set last time (kept in <session>.tag). A name the
# person gave it stays, and so does one another agent in the same tab set first.
if [ -n "${HC_TERMINAL_ID:-}" ] && command -v herdr-app >/dev/null 2>&1; then
  tag=$(printf '%s' "$2" | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//' | cut -c1-24)
  last_file="$dir/$CLAUDE_CODE_SESSION_ID.tag"
  last=$(cat "$last_file" 2>/dev/null || true)
  herdr-app ls 2>/dev/null | /usr/bin/python3 -c '
import json, subprocess, sys
term, tag, last = sys.argv[1:4]
try:
    for s in json.load(sys.stdin)["spaces"]:
        for t in s["tabs"]:
            if any(x.get("terminal") == term for x in t.get("terminals", [])):
                name = t.get("name", "")
                if name != tag and (name.isdigit() or (last and name == last)):
                    subprocess.run(["herdr-app", "do", "tab.rename", json.dumps({"id": t["id"], "name": tag})], capture_output=True)
                raise SystemExit
except SystemExit:
    pass
except Exception:
    pass
' "$HC_TERMINAL_ID" "$tag" "$last" >/dev/null 2>&1 || true
  printf '%s' "$tag" > "$last_file"
fi
