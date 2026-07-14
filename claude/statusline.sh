#!/bin/bash
# Claude Code status line — renders: Model-Name-effort — <what this session is doing, ~50 chars>
# e.g. "Opus-4.8-high — Fix flaky combat e2e test". The effort suffix is the reasoning
# level (.effort.level: high/medium/low); dropped when absent.
# Receives session JSON on stdin (see https://code.claude.com/docs/en/statusline).
#
# Description priority (first non-empty wins):
#   1. agent label        — set-label.sh wrote it (the agent's own headline)
#   2. session_name       — an explicit /rename, OR the harness's AUTO-generated
#                           session title (see below — this is why it's #2 now)
#   3. in-progress todo    — the agent's current TodoWrite item (activeForm)
#   4. latest typed prompt — the most recent thing the human typed
#   5. (model name only)
#
# NOTE (2026-07-04): .session_name used to be #1 on the theory that it's only set
# by an explicit human /rename. That's no longer true — this harness AUTO-populates
# .session_name with a generated title (e.g. "Fix broken status line"), so keeping
# it first silently clobbered every set-label.sh headline on every render. The
# agent label now wins; to show an auto-title/rename instead, just don't set a
# label. (If a future harness exposes a separate "was renamed by human" signal,
# reinstate that as the real #1.)
input=$(cat)

# Side-effect: cache the plan-usage rate limits (5h/7d windows) that the harness
# includes in this payload, so `~/.claude/usage.sh` can print them on demand from
# any terminal. Only written when the payload actually carries rate_limits (it
# appears after the first API response of a session). Rendering is unaffected.
rl=$(printf '%s' "$input" | jq -c '.rate_limits // empty' 2>/dev/null)
if [ -n "$rl" ]; then
  printf '%s' "$input" | jq -c '{cached_at: now, model: (.model.display_name // "unknown"), rate_limits}' \
    > "$HOME/.claude/usage-cache.json" 2>/dev/null
fi

model=$(printf '%s' "$input" | jq -r '.model.display_name // "unknown"' | tr ' ' '-')
# Append the reasoning-effort level (.effort.level: low/medium/high/xhigh/max) →
# "Opus-4.8-high". Absent when the model doesn't support effort — then no suffix.
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')
[ -n "$effort" ] && model="${model}-${effort}"
name=$(printf  '%s' "$input" | jq -r '.session_name // empty')
sid=$(printf   '%s' "$input" | jq -r '.session_id // empty')
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')

desc=""

# 1. Agent-written label (set-label.sh) — the intentional headline for THIS
#    session, and the reason this status line exists. Checked FIRST: the harness
#    now auto-populates .session_name, so if session_name went first (as it used
#    to) it would clobber the label on every render.
#    set-label.sh keys the file by the $CLAUDE_CODE_SESSION_ID env var; this status
#    payload gives us .session_id. They're normally identical, but if they ever
#    diverge (payload omits/renames session_id, a resumed session, etc.) the
#    single-key lookup silently misses. So try BOTH keys — the JSON id first
#    (authoritative for THIS render), then the env id set-label.sh wrote under —
#    and take the first that names a non-empty label file.
if [ -z "$desc" ]; then
  for candidate in "$sid" "$CLAUDE_CODE_SESSION_ID"; do
    [ -n "$candidate" ] || continue
    label_file="$HOME/.claude/session-labels/$candidate.label"
    if [ -f "$label_file" ]; then
      desc=$(cat "$label_file")
      [ -n "$desc" ] && break
    fi
  done
fi

# 2. session_name — an explicit /rename, or the harness's auto-generated title.
[ -z "$desc" ] && desc="$name"

# 3. In-progress TODO (most recent TodoWrite in the transcript; prefer in_progress,
#    else first pending). Uses activeForm ("Wiring …") when present.
if [ -z "$desc" ] && [ -n "$transcript" ] && [ -f "$transcript" ]; then
  desc=$(jq -rs '
    [ .[]
      | select(.type == "assistant")
      | (.message.content? // [])
      | if type == "array" then .[] else empty end
      | select(type == "object" and .type == "tool_use" and .name == "TodoWrite")
      | .input.todos
    ]
    | last // []
    | ( map(select(.status == "in_progress")) + map(select(.status == "pending")) )[0] // {}
    | (.activeForm // .content // "")
  ' "$transcript" 2>/dev/null)
fi

# 4. Fallback: latest typed user prompt (skips tool-result messages).
if [ -z "$desc" ] && [ -n "$transcript" ] && [ -f "$transcript" ]; then
  desc=$(jq -rs '
    [ .[]
      | select(.type == "user")
      | .message.content
      | if   type == "string" then .
        elif type == "array"  then ([.[] | select(.type == "text") | .text] | join(" "))
        else empty end
      | select(type == "string" and length > 0)
    ] | last // ""
  ' "$transcript" 2>/dev/null)
fi

# Collapse whitespace, truncate to 50 chars.
desc=$(printf '%s' "$desc" | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//')
if [ "${#desc}" -gt 50 ]; then
  desc="${desc:0:49}…"
fi

if [ -n "$desc" ]; then
  printf '%s — %s' "$model" "$desc"
else
  printf '%s' "$model"
fi
