#!/bin/bash
# Shared audit logger + hook-payload parser for the Claude Code sound hooks.
#
# Source this (`. "$(dirname "$0")/audit.sh"`); it provides:
#   SOUND_LOG            - the audit log path (override with $SOUND_LOG)
#   sound_audit KV...    - append one timestamped line of `key=value` tokens
#   sound_parse_payload  - parse a hook JSON payload ($1) into HK_* globals
#   sound_short ID       - first 8 chars of an id, for readable log lines
#
# The whole point of this file is debuggability: every chime (and every
# suppressed chime) lands in one log with enough context — event, session,
# cwd, pending-work counts, reason — to answer "what made that noise and why".
#   tail -f ~/.claude/sounds/play.log

SOUND_LOG="${SOUND_LOG:-$HOME/.claude/sounds/play.log}"

# Append one structured line: "<timestamp>\t<key=val> <key=val> ...".
# Never fails the caller (logging must not break a hook).
sound_audit() {
  printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$SOUND_LOG" 2>/dev/null || true
}

# Parse a hook JSON payload (arg $1) into globals. Degrades to safe defaults
# (empty strings / 0 counts) if jq is missing or the JSON is unreadable.
#   HK_SESSION HK_CWD HK_EVENT HK_BG HK_CRON HK_STOPACTIVE HK_JQ
sound_parse_payload() {
  local payload="$1"
  HK_SESSION=""; HK_CWD=""; HK_EVENT=""; HK_BG=0; HK_CRON=0; HK_STOPACTIVE=""
  HK_JQ=0
  command -v jq >/dev/null 2>&1 || return 0
  [ -n "$payload" ] || return 0
  HK_JQ=1
  HK_SESSION=$(printf '%s' "$payload"   | jq -r '.session_id // ""' 2>/dev/null)
  HK_CWD=$(printf '%s' "$payload"       | jq -r '.cwd // ""' 2>/dev/null)
  HK_EVENT=$(printf '%s' "$payload"     | jq -r '.hook_event_name // ""' 2>/dev/null)
  HK_BG=$(printf '%s' "$payload"        | jq -r '(.background_tasks // []) | length' 2>/dev/null)
  HK_CRON=$(printf '%s' "$payload"      | jq -r '(.session_crons // []) | length' 2>/dev/null)
  HK_STOPACTIVE=$(printf '%s' "$payload"| jq -r '.stop_hook_active // ""' 2>/dev/null)
  [ -n "$HK_BG" ]   || HK_BG=0
  [ -n "$HK_CRON" ] || HK_CRON=0

  # Opt-in raw-payload capture for deep debugging of unknown fields.
  if [ -n "$CC_SOUND_DEBUG" ]; then
    printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${HK_EVENT:-?}" "$payload" \
      >> "$HOME/.claude/sounds/payload-debug.log" 2>/dev/null || true
  fi
}

# First 8 chars of an id (session ids are long uuids; 8 is enough to correlate).
sound_short() { printf '%s' "${1:0:8}"; }
