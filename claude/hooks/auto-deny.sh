#!/usr/bin/env bash
#
# PermissionRequest hook: answer every permission dialog with "deny", plus a
# reason the agent can act on.
#
# No session on this machine should ever stop for a yes/no: an unanswered
# dialog stalls an unattended agent for hours (one sat 23h, 2026-07-31).
# dontAsk sessions already turn an ask into a deny, but bypassPermissions
# sessions still show Claude Code's built-in Bash safety prompt for commands it
# cannot statically verify, e.g. a loop running `bash -c "$s"` (2026-10-09, the
# "TODO shardfile plan" session). This hook answers that dialog with a deny
# right away, so the agent rewrites the command instead of waiting.
#
# Deny, not allow (Jake, 2026-10-09): auto-allowing whatever the safety check
# could not verify is too dangerous; a fast refusal keeps the session moving.
#
# Left alone (they are conversations with the human, not permission checks):
# AskUserQuestion, ExitPlanMode, EnterPlanMode, and anything in plan mode.
#
# Every decision is appended to ~/.claude/auto-deny.log.

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"
mode="$(printf '%s' "$payload" | jq -r '.permission_mode // ""')"
session="$(printf '%s' "$payload" | jq -r '.session_id // ""')"
summary="$(printf '%s' "$payload" | jq -r '.tool_input.command // .tool_input.file_path // "" | tostring' | tr '\n' ' ' | cut -c1-200)"

log() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$1" "$session" "$mode" "$tool" "$summary" \
    >>"$HOME/.claude/auto-deny.log" 2>/dev/null
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

log deny
reason="Auto-denied: this call needed a permission prompt, and sessions on this machine never wait on one. \
Nobody is watching the dialog. Rewrite it so it can be verified statically: run each command directly \
instead of through bash -c \"\$var\", eval or a variable holding a command; or write the steps to a script \
file in your scratchpad and run that file. If it truly needs a human, tell Jake in your reply instead."
jq -nc --arg m "$reason" \
  '{hookSpecificOutput: {hookEventName: "PermissionRequest", decision: {behavior: "deny", message: $m}}}'
