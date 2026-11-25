#!/bin/bash
# Set THIS session's status-line label + its Herdr tag (app tab name, goal label).
# Usage:  ~/.claude/set-label.sh "<=50 char goal, PR-title style>" "<=24 char tag>"
#   arg 1 (required): the status-line goal — QUOTE it (it's one argument now).
#   arg 2 (required): a short tag for Herdr: the hc label goal=<tag> (shown by
#                     the session-agents mod) and the app tab's name. Mandatory so
#                     every goal update refreshes both; capped at 24 chars.
# Keyed by $CLAUDE_CODE_SESSION_ID, so every concurrent session has its own label.
[ -n "$CLAUDE_CODE_SESSION_ID" ] || { echo "no CLAUDE_CODE_SESSION_ID" >&2; exit 0; }
if [ "$#" -lt 2 ] || [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo 'usage: set-label.sh "<goal>" "<tag, <=24 chars>"  (both required)' >&2
  exit 2
fi
dir="$HOME/.claude/session-labels"
mkdir -p "$dir"
label=$(printf '%s' "$1" | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//' | cut -c1-50)
printf '%s' "$label" > "$dir/$CLAUDE_CODE_SESSION_ID.label"

# The tag, one line, capped at 24 chars: short enough for a tab name and an
# agents-panel row.
tag=$(printf '%s' "$2" | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//' | cut -c1-24)

# herdr-core (hc) runs every terminal and sets $HC_TERMINAL_ID. The tag goes
# on the terminal as label goal=<tag>; the session-agents mod in
# .config/herdr-app shows it on the agent's row. This works on every machine,
# including the mini, which has no window for the tab rename below.
if [ -n "${HC_TERMINAL_ID:-}" ] && command -v hc >/dev/null 2>&1; then
  hc label "$HC_TERMINAL_ID" goal="$tag" >/dev/null 2>&1 || true
fi

# The Herdr desktop app (herdr-app; terminals run in herdr-core, which sets
# $HC_TERMINAL_ID). An unnamed tab is called by its number, and the app's Go-to picker (cmd-p) lists agents by tab
# name: every agent showed as "1" (Jake, 2026-11-19: "why are these things 1").
# So the tab takes the tag while its name is still a number (nobody named it) or
# is the tag this session set last time (kept in <session>.tag). A name the
# person gave it stays, and so does one another agent in the same tab set first.
if [ -n "${HC_TERMINAL_ID:-}" ] && command -v herdr-app >/dev/null 2>&1; then
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
