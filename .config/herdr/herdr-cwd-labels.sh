#!/bin/bash
#
# herdr-cwd-labels — publish each workspace's working directory into the herdr
# spaces sidebar as the `$cwd` token.
#
# WHY THIS EXISTS AS A POLLER: herdr emits no events. `herdr api` offers exactly
# two verbs (`snapshot`, `schema`) and config.toml has no hook/event section, so
# nothing can subscribe to "a pane changed directory". Re-reading the snapshot on
# an interval is the only mechanism available (verified against herdr 0.7.5).
#
# WHICH cwd REPRESENTS A WORKSPACE: a workspace can hold panes in different
# directories (w1 routinely has one pane in ~/projects/personal and another in
# ~/projects/dotfiles). The rule is: most common cwd across the workspace's
# panes, ties broken by the FIRST pane's cwd — never an arbitrary pick, so the
# label is stable across runs given the same layout.
#
# Usage:
#   herdr-cwd-labels.sh            one shot, update every workspace and exit
#   herdr-cwd-labels.sh --watch    loop until the herdr server goes away
#
# The token is written with a TTL of 3x the poll interval. If the watcher dies,
# the labels expire and the row disappears rather than silently showing a
# directory you left ten minutes ago. A row whose tokens are all empty renders
# nothing, which is exactly the behaviour we want here.
#
# Pairs with the `$cwd` token in the [ui.sidebar.spaces] rows of config.toml.
# Both halves are required — writing the token without a row that asks for it by
# name renders nothing, silently.

set -uo pipefail

INTERVAL="${HERDR_CWD_INTERVAL:-10}"
TTL_MS=$(( INTERVAL * 3 * 1000 ))
SOURCE="herdr:cwd"

# Path prettifier. ~/projects is the overwhelmingly common prefix and eats 10 of
# the ~26 usable sidebar columns, so it collapses to `~prj`. Everything else
# under $HOME just gets the normal `~`.
abbrev_paths() {
    python3 -c '
import json, os, sys
from collections import Counter

try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(1)

snap = doc.get("result", {}).get("snapshot")
if not snap:
    sys.exit(1)

home = os.path.expanduser("~")

def pretty(path):
    if path == home:
        return "~"
    if path.startswith(home + "/projects/"):
        return "~prj/" + path[len(home) + len("/projects/"):]
    if path == home + "/projects":
        return "~prj"
    if path.startswith(home + "/"):
        return "~/" + path[len(home) + 1:]
    return path

# Preserve snapshot order so "first pane" is well defined.
by_ws = {}
for pane in snap.get("panes", []):
    cwd = pane.get("cwd")
    if not cwd:
        continue
    by_ws.setdefault(pane["workspace_id"], []).append(cwd)

for ws_id, cwds in by_ws.items():
    counts = Counter(cwds)
    top = max(counts.values())
    tied = {c for c, n in counts.items() if n == top}
    # Ties resolve to whichever tied cwd appears earliest, i.e. the first pane.
    winner = next(c for c in cwds if c in tied)
    print("%s\t%s" % (ws_id, pretty(winner)))
'
}

publish_once() {
    local snapshot
    snapshot=$(herdr api snapshot 2>/dev/null) || return 1
    [ -n "$snapshot" ] || return 1

    local ws_id label
    while IFS=$'\t' read -r ws_id label; do
        [ -n "$ws_id" ] || continue
        herdr workspace report-metadata "$ws_id" \
            --source "$SOURCE" \
            --token "cwd=$label" \
            --ttl-ms "$TTL_MS" >/dev/null 2>&1 || true
    done < <(printf '%s' "$snapshot" | abbrev_paths)
}

if [ "${1:-}" = "--watch" ]; then
    # Single watcher per host. mkdir is the atomic test-and-set that's portable
    # to macOS, which has no flock(1).
    lock="${TMPDIR:-/tmp}/herdr-cwd-labels.lock"
    mkdir "$lock" 2>/dev/null || exit 0
    trap 'rmdir "$lock" 2>/dev/null' EXIT INT TERM

    while herdr api snapshot >/dev/null 2>&1; do
        publish_once
        sleep "$INTERVAL"
    done
    exit 0
fi

publish_once
