#!/bin/bash
# Append one line of Claude plan usage per run to ~/.claude/usage-log/<ISO week>.jsonl (append-only, never rewritten).
# Run hourly from cron:  17 * * * * /Users/raynos/.claude/usage-log.sh
#
# Each line: when, the account Claude Code is logged in as (~/.claude.json oauthAccount → email + uuid, so /login
# swaps show up), and every Claude account OpenUsage tracks (5h session, weekly, Fable weekly: used % + resets).
# Source: `openusage claude` (OpenUsage.app's shared 5-minute cache). Read the week with:
#   jq -r '[.at, .active_email, (.accounts[] | "\(.name): wk \(.weekly_used)% 5h \(.session_used)%")] | join("  ")' \
#     ~/.claude/usage-log/$(date -u +%G-W%V).jsonl
set -uo pipefail
dir="$HOME/.claude/usage-log"
mkdir -p "$dir"
raw="$(/usr/local/bin/openusage claude 2>/dev/null || true)"
line="$(RAW="$raw" /usr/bin/python3 - <<'PY'
import json, os, datetime
now = datetime.datetime.now(datetime.timezone.utc)
out = {"at": now.strftime("%Y-%m-%dT%H:%M:%SZ")}
try:
    oa = json.load(open(os.path.expanduser("~/.claude.json"))).get("oauthAccount") or {}
    out["active_email"] = oa.get("emailAddress")
    out["active_account"] = oa.get("accountUuid")
    out["active_tier"] = oa.get("organizationRateLimitTier")
except Exception as e:
    out["active_error"] = str(e)[:200]
accts = []
try:
    d = json.loads(os.environ.get("RAW") or "{}")
    for pid, p in (d.get("providers") or {}).items():
        r = p.get("resources") or {}
        g = lambda k, f: (r.get(k) or {}).get(f)
        accts.append({"id": pid, "name": (p.get("displayName") or "").replace("Claude — ", ""),
                      "plan": p.get("plan"), "stale": p.get("stale"),
                      "weekly_used": g("weekly", "used"), "weekly_resets": g("weekly", "resetsAt"),
                      "session_used": g("session", "used"), "session_resets": g("session", "resetsAt"),
                      "fable_used": g("fable", "used")})
    if d.get("errors"): out["errors"] = d["errors"]
except Exception as e:
    out["openusage_error"] = str(e)[:200]
out["accounts"] = accts
print(json.dumps(out, separators=(",", ":")))
PY
)"
[ -n "$line" ] && printf '%s\n' "$line" >> "$dir/$(date -u +%G-W%V).jsonl"
