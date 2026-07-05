#!/bin/bash
# Notification-hook sound: permission-prompt vs. generic question, with audit
# logging. Replaces the inline one-liner that used to live in settings.json, so
# these chimes are traceable too (session, cwd, which category, why).
payload=$(cat)
dir="$(dirname "$0")"
. "$dir/audit.sh"
sound_parse_payload "$payload"
sess=$(sound_short "$HK_SESSION")

# Same classification the old inline hook used: a payload mentioning
# "permission" is a permission prompt; everything else is a generic question.
if printf '%s' "$payload" | grep -qi permission; then
  cat=permission
else
  cat=question
fi

export CC_SOUND_EVENT=Notification
export CC_SOUND_SESSION="$sess"
export CC_SOUND_CWD="$HK_CWD"
export CC_SOUND_REASON="notification"
exec "$dir/play.sh" "$cat"
