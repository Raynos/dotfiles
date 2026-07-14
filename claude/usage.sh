#!/bin/bash
# Print Claude Code plan usage from the statusline cache, e.g.:
#   Fable 5 | 5hr: 87% (resets 21:00) | 7d: 100% (resets Thu 09:00) | cached 12s ago
#
# Data source: ~/.claude/usage-cache.json, written by statusline.sh on every
# statusline render (any active Claude Code session). There is no reliable
# standalone endpoint for this — the OAuth /api/oauth/usage endpoint 429s
# aggressively (anthropics/claude-code#31637) — so we piggyback on the
# statusline payload's .rate_limits instead. If no session has rendered a
# statusline since login, the cache won't exist yet.
set -euo pipefail

cache="$HOME/.claude/usage-cache.json"
if [ ! -f "$cache" ]; then
  echo "no usage cache yet — open any Claude Code session (statusline writes it)" >&2
  exit 1
fi

fmt_reset() {
  # Accepts epoch seconds or ISO8601; prints a short local time.
  local v="$1"
  if [ -z "$v" ] || [ "$v" = "null" ]; then
    printf '?'
  elif [[ "$v" =~ ^[0-9]+$ ]]; then
    # Same-day resets → HH:MM; otherwise Day HH:MM.
    if [ "$(date -r "$v" +%Y%m%d)" = "$(date +%Y%m%d)" ]; then
      date -r "$v" +%H:%M
    else
      date -r "$v" '+%a %H:%M'
    fi
  else
    printf '%s' "$v"
  fi
}

model=$(jq -r '.model // "unknown"' "$cache")
cached_at=$(jq -r '.cached_at // 0 | floor' "$cache")
h5=$(jq -r '.rate_limits.five_hour.used_percentage // empty' "$cache")
h5r=$(jq -r '.rate_limits.five_hour.resets_at // empty' "$cache")
d7=$(jq -r '.rate_limits.seven_day.used_percentage // empty' "$cache")
d7r=$(jq -r '.rate_limits.seven_day.resets_at // empty' "$cache")
# Some payload versions carry extra windows (e.g. per-model opus buckets);
# print any we don't explicitly format so nothing is silently hidden.
extra=$(jq -r '.rate_limits | del(.five_hour, .seven_day) | to_entries[]?
  | "\(.key): \(.value.used_percentage // "?")%"' "$cache" 2>/dev/null)

age=$(( $(date +%s) - cached_at ))
if   [ "$age" -lt 120 ];  then age_s="${age}s ago"
elif [ "$age" -lt 7200 ]; then age_s="$((age / 60))m ago"
else                           age_s="$((age / 3600))h ago"
fi

line="$model"
[ -n "$h5" ] && line="$line | 5hr: ${h5%.*}% (resets $(fmt_reset "$h5r"))"
[ -n "$d7" ] && line="$line | 7d: ${d7%.*}% (resets $(fmt_reset "$d7r"))"
[ -n "$extra" ] && line="$line | $(printf '%s' "$extra" | tr '\n' ' ' | sed 's/ $//')"
line="$line | cached $age_s"
echo "$line"
