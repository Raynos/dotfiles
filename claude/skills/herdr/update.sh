#!/bin/sh
# Refresh ~/.claude/skills/herdr/SKILL.md from the canonical upstream herdr agent
# guide, so the skill never goes stale. Safe, idempotent, re-run any time:
#
#   ~/.claude/skills/herdr/update.sh
#
# herdr ships no official skill-install command (verified 2026-07-04). Upstream's
# SKILL.md already carries valid Claude-skill frontmatter (name + description), so
# we install it VERBATIM — zero local edits, zero drift. Provenance + this update
# recipe live in the sibling README.md, which never affects skill parsing.
set -eu

DIR="$(CDPATH= cd "$(dirname "$0")" && pwd)"
SRC="https://raw.githubusercontent.com/ogulcancelik/herdr/master/SKILL.md"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT HUP INT TERM

if ! curl -fsSL "$SRC" -o "$TMP"; then
  echo "herdr skill update: failed to fetch $SRC — leaving existing SKILL.md untouched" >&2
  exit 1
fi
if [ ! -s "$TMP" ]; then
  echo "herdr skill update: upstream returned empty — leaving existing SKILL.md untouched" >&2
  exit 1
fi
# Sanity: upstream must still start with YAML frontmatter, or it is not a valid skill.
if ! head -1 "$TMP" | grep -q '^---'; then
  echo "herdr skill update: upstream no longer starts with frontmatter — refusing to install" >&2
  exit 1
fi

mv "$TMP" "$DIR/SKILL.md"
trap - EXIT HUP INT TERM
echo "herdr skill: refreshed $DIR/SKILL.md from upstream ($(wc -l < "$DIR/SKILL.md" | tr -d ' ') lines)"
