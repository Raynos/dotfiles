#!/usr/bin/env bash
#
# PermissionRequest hook: answer every permission dialog with "allow".
#
# Sessions here run bypassPermissions or dontAsk, so no tool call should ever
# stop for a yes/no. Claude Code still raises its own built-in Bash safety
# prompt in bypass mode for commands it cannot statically verify, e.g. a loop
# that runs `bash -c "$s"` (2026-10-09, the "TODO shardfile plan" session).
# This hook answers that dialog before anyone has to.
#
# Safety still comes from the PreToolUse hooks, which run first: dcg and
# guard-rm.py deny destructive commands with a reason, and settings.json's
# deny rules still apply. This hook only removes the interactive yes/no.
#
# Left alone (they are conversations with the human, not permission checks):
# AskUserQuestion, ExitPlanMode, EnterPlanMode, and anything in plan mode.
#
# Every decision is appended to ~/.claude/auto-allow.log.

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"
mode="$(printf '%s' "$payload" | jq -r '.permission_mode // ""')"
session="$(printf '%s' "$payload" | jq -r '.session_id // ""')"
summary="$(printf '%s' "$payload" | jq -r '.tool_input.command // .tool_input.file_path // "" | tostring' | tr '\n' ' ' | cut -c1-200)"

log() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$1" "$session" "$mode" "$tool" "$summary" \
    >>"$HOME/.claude/auto-allow.log" 2>/dev/null
}

case "$tool" in
  AskUserQuestion | ExitPlanMode | EnterPlanMode)
    log pass
    exit 0
    ;;
esac
if [ "$mode" = "plan" ]; then
  log pass
  exit 0
fi

log allow
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
