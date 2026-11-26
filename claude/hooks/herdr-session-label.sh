#!/usr/bin/env bash
# SessionStart / SessionEnd hook: remember which Claude session runs in which
# herdr-core terminal, so bin/herdr-resume can bring it back after a reboot.
#
# The old Herdr TUI did this itself (its hook sent pane.report_agent_session
# and the TUI reran `claude --resume <id>`). herdr-core has no such feature:
# `hc keep` brings a lost terminal back as a bare shell, never the program.
# So this hook writes the session onto the terminal as hc labels, which
# survive core restarts and reboots:
#
#   claude_session=<session id>   claude_cwd=<folder claude started in>
#
# SessionStart (startup, resume, clear, compact) sets them; the newest session
# in a terminal wins. SessionEnd clears them only when the person quit on
# purpose (/exit, ctrl-d, logout), so a reboot, crash or kill leaves them for
# herdr-resume. Subagents and terminals outside herdr-core are skipped. Never
# fails the session: every error is swallowed.

[ -n "${HC_TERMINAL_ID:-}" ] || exit 0
hc=$(command -v hc 2>/dev/null || true)
[ -n "$hc" ] || hc="$HOME/.local/bin/hc"
[ -x "$hc" ] || exit 0

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

args=$(printf '%s' "$input" | /usr/bin/python3 -c '
import json, sys
try:
    h = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if h.get("agent_id"):
    sys.exit(0)
event = h.get("hook_event_name")
sid = h.get("session_id") or ""
cwd = h.get("cwd") or ""
if event == "SessionStart" and sid and cwd:
    print("claude_session=" + sid)
    print("claude_cwd=" + cwd)
elif event == "SessionEnd" and h.get("reason") in ("prompt_input_exit", "logout"):
    print("claude_session=")
    print("claude_cwd=")
' 2>/dev/null) || exit 0
[ -n "$args" ] || exit 0

labels=()
while IFS= read -r line; do labels+=("$line"); done <<<"$args"
"$hc" label "$HC_TERMINAL_ID" "${labels[@]}" >/dev/null 2>&1 || true
exit 0
