#!/bin/bash
# UserPromptSubmit hook: if this session's status-line label is missing or stale,
# nudge the agent (once per cooldown) to run set-label.sh. Pure shell, no LLM,
# no background process, no sound. For UserPromptSubmit, stdout (exit 0) is added
# to the model's context.
STALE=1200     # label considered stale after 20 min
COOLDOWN=1200  # nudge at most once per 20 min, even if still unset

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
[ -n "$sid" ] || exit 0

dir="$HOME/.claude/session-labels"
label="$dir/$sid.label"
remind="$dir/$sid.remind"

# Fresh label? nothing to do.
if [ -f "$label" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$label") ))
  [ "$age" -lt "$STALE" ] && exit 0
fi

# Stale/missing — but respect the nudge cooldown so we never nag every turn.
if [ -f "$remind" ]; then
  rage=$(( $(date +%s) - $(stat -f %m "$remind") ))
  [ "$rage" -lt "$COOLDOWN" ] && exit 0
fi

mkdir -p "$dir"
touch "$remind"
echo "[status-line reminder] This session's status-line label is unset or stale. If the high-level goal is clear, set it (<=50 chars, PR-title style): ~/.claude/set-label.sh \"your goal\". Skip if the goal is still ambiguous."
exit 0
