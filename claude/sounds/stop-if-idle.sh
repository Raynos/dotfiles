#!/bin/bash
# Smart Stop-gate for the "complete" chime — with full audit logging.
#
# The Stop hook fires at EVERY turn-end yield, not just true idle — including
# mid-loop continuations and pauses while a background task / subagent / workflow
# / cron is still running (Claude Code surfaces these as `background_tasks` /
# `session_crons` in the payload, v2.1.145+). We chime ONLY when the session is
# genuinely waiting for the human: both arrays empty.
#
# Fails OPEN: if we can't read the payload (no jq / bad JSON / old CLI), we PLAY
# and say so in the log. Prefer a false chime over a missed idle.
#
# EVERY decision — PLAY or SUPPRESS — is logged to ~/.claude/sounds/play.log with
# the session id, cwd, and pending-work counts, so a mystery chime (or a mystery
# silence) is always traceable:  tail -f ~/.claude/sounds/play.log
payload=$(cat)
dir="$(dirname "$0")"
. "$dir/audit.sh"
sound_parse_payload "$payload"

sess=$(sound_short "$HK_SESSION")
pending=$(( HK_BG + HK_CRON ))

# Positively-confirmed pending work → stay silent, but log why.
if [ "$HK_JQ" = "1" ] && [ "$pending" -gt 0 ] 2>/dev/null; then
  sound_audit "event=Stop decision=SUPPRESS cat=complete reason=pending-work" \
              "bg=$HK_BG cron=$HK_CRON stop_active=$HK_STOPACTIVE" \
              "session=$sess cwd=$HK_CWD ppid=$PPID"
  exit 0
fi

# Idle (or fail-open) → play. Reason distinguishes a real idle read from a
# jq-less fail-open so the log doesn't lie about what we actually knew.
if [ "$HK_JQ" = "1" ]; then
  reason="idle(bg=$HK_BG,cron=$HK_CRON)"
else
  reason="fail-open(no-jq)"
fi

# Hand context to play.sh so its PLAY line carries the same session/cwd/reason.
export CC_SOUND_EVENT=Stop
export CC_SOUND_SESSION="$sess"
export CC_SOUND_CWD="$HK_CWD"
export CC_SOUND_REASON="$reason"
exec "$dir/play.sh" complete
