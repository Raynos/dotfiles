#!/bin/bash
# Play a random Warcraft 3 sound for the given category.
# Usage: play.sh <complete|question|permission>
# Volume can be overridden with CC_SOUND_VOL (afplay -v, 1.0 = 100%).
cat="${1:-complete}"
dir="$HOME/.claude/sounds/warcraft3-en"
# Per-category default volume; question is boosted so decision/ask prompts
# aren't easy to miss. Override any of them with CC_SOUND_VOL.
case "$cat" in
  question) def_vol=1.5 ;;
  *)        def_vol=1.25 ;;
esac
vol="${CC_SOUND_VOL:-$def_vol}"
# Collect matching files into an array.
files=("$dir/$cat"-*.wav)
# Bail quietly if none found (e.g. category not downloaded).
[ -e "${files[0]}" ] || exit 0
pick="${files[RANDOM % ${#files[@]}]}"
# Audit trail: record every actual play so mystery chimes are traceable.
# Context (event/session/cwd/reason) is passed in by the calling hook via
# CC_SOUND_* env vars; when play.sh is run by hand they default to "direct".
# tail -f ~/.claude/sounds/play.log to watch what's firing.
. "$(dirname "$0")/audit.sh"
sound_audit "event=${CC_SOUND_EVENT:-direct} decision=PLAY cat=$cat" \
            "reason=${CC_SOUND_REASON:-manual} session=${CC_SOUND_SESSION:-} " \
            "file=$(basename "$pick") vol=$vol cwd=${CC_SOUND_CWD:-} ppid=$PPID"
exec afplay -v "$vol" "$pick"
