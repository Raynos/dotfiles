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
# ONE WATCHER PER SESSION, NOT PER HOST: every named herdr session
# (`herdr session list`) is a separate server process with its own socket and its
# own workspace ids, and metadata is per-server — publishing to one does nothing
# for the others. This script therefore pins itself to exactly one session and
# locks per session name, so a watcher can run for each one concurrently.
# It used to take a single host-wide lock and call bare `herdr`, which meant the
# first watcher to start won the lock and published to whichever session its env
# happened to resolve to (`default`, when launched from outside a pane) — so
# `$cwd` silently only ever worked in one session.
#
# Usage:
#   herdr-cwd-labels.sh [--session <name>]           one shot, then exit
#   herdr-cwd-labels.sh [--session <name>] --watch   loop until that server goes
#
# Without --session the target is taken from $HERDR_SESSION / $HERDR_SOCKET_PATH
# (both set inside a herdr pane), falling back to the `default` session. Pass
# --session explicitly when launching from outside a pane, where that env is
# absent — e.g. bin/herdr-attach, which starts one watcher per session it
# attaches.
#
# The token is written with a TTL of 3x the poll interval. If the watcher dies,
# the labels expire and the row disappears rather than silently showing a
# directory you left ten minutes ago. A row whose tokens are all empty renders
# nothing, which is exactly the behaviour we want here. The same TTL is what
# heals a `herdr server reload-config`: a reload clears runtime metadata, so the
# `$cwd` row blanks until the next poll re-publishes it.
#
# Pairs with the `$cwd` token in the [ui.sidebar.spaces] rows of config.toml.
# Both halves are required — writing the token without a row that asks for it by
# name renders nothing, silently.

set -uo pipefail

INTERVAL="${HERDR_CWD_INTERVAL:-10}"
TTL_MS=$(( INTERVAL * 3 * 1000 ))
SOURCE="herdr:cwd"
CONFIG_DIR="$HOME/.config/herdr"
# Seconds to wait for a not-yet-running server's socket (watch mode only).
SOCKET_WAIT="${HERDR_CWD_SOCKET_WAIT:-30}"

WATCH=0
SESSION=""

usage() {
    cat <<'EOF'
usage: herdr-cwd-labels.sh [--session <name>] [--watch]

Publish each workspace's working directory as the herdr `$cwd` sidebar token,
for ONE session. Without --session the target comes from $HERDR_SESSION /
$HERDR_SOCKET_PATH, falling back to the `default` session.

  --session <name>  target that named session (required from outside a pane)
  --watch           poll until that session's server goes away
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --watch)
            WATCH=1
            shift ;;
        --session)
            [ "$#" -ge 2 ] || { printf '%s: --session needs a name\n' "${0##*/}" >&2; exit 2; }
            SESSION="$2"
            shift 2 ;;
        --session=*)
            SESSION="${1#*=}"
            shift ;;
        -h|--help)
            usage
            exit 0 ;;
        *)
            printf '%s: unknown argument %s\n' "${0##*/}" "$1" >&2
            usage >&2
            exit 2 ;;
    esac
done

# `default` lives at the config root; every named session gets a subdirectory.
# This mirrors the `socket` column of `herdr session list` (herdr 0.7.5).
socket_for_session() {
    if [ "$1" = "default" ]; then
        printf '%s/herdr.sock' "$CONFIG_DIR"
    else
        printf '%s/sessions/%s/herdr.sock' "$CONFIG_DIR" "$1"
    fi
}

session_from_socket() {
    local dir
    dir=$(dirname "$1")
    case "$dir" in
        */sessions/*) printf '%s' "${dir##*/}" ;;
        *)            printf 'default' ;;
    esac
}

# Resolve the target ONCE, up front. An inherited $HERDR_SOCKET_PATH wins over
# reconstructing the path from the name, so a non-conventional socket location
# still works; the name is then only used to key the lock.
SOCKET=""
if [ -n "$SESSION" ]; then
    SOCKET=$(socket_for_session "$SESSION")
elif [ -n "${HERDR_SOCKET_PATH:-}" ]; then
    SOCKET="$HERDR_SOCKET_PATH"
    SESSION="${HERDR_SESSION:-$(session_from_socket "$SOCKET")}"
elif [ -n "${HERDR_SESSION:-}" ]; then
    SESSION="$HERDR_SESSION"
    SOCKET=$(socket_for_session "$SESSION")
else
    SESSION="default"
    SOCKET=$(socket_for_session "$SESSION")
fi

# The name keys a filesystem path, so keep it to the charset herdr itself allows.
case "$SESSION" in
    ""|*[!A-Za-z0-9._-]*)
        printf '%s: refusing unsafe session name %s\n' "${0##*/}" "$SESSION" >&2
        exit 2 ;;
esac

# COLD-START RACE: bin/herdr-attach has to launch the watcher *before* it calls
# `herdr session attach`, because attach blocks until you detach. So on a session
# that isn't running yet, the socket appears a moment after we start. Wait for it
# in watch mode; fail fast in one-shot mode, where there is nothing to wait for.
if [ ! -S "$SOCKET" ] && [ "$WATCH" = 1 ]; then
    waited=0
    while [ ! -S "$SOCKET" ] && [ "$waited" -lt "$SOCKET_WAIT" ]; do
        sleep 1
        waited=$(( waited + 1 ))
    done
fi

if [ ! -S "$SOCKET" ]; then
    printf '%s: no running herdr server for session %s (%s)\n' \
        "${0##*/}" "$SESSION" "$SOCKET" >&2
    exit 1
fi

# Pin every `herdr` call below to that one server. Both vars are exported and
# kept consistent so it does not matter which the CLI prefers.
export HERDR_SESSION="$SESSION"
export HERDR_SOCKET_PATH="$SOCKET"

# Path prettifier. ~/projects is the overwhelmingly common prefix and eats 10 of
# the ~26 usable sidebar columns, so it collapses to `~prj`. Everything else
# under $HOME just gets the normal `~`.
#
# PATH_ALIASES below go one better: a project group that has its own herdr
# session is noise in the label (inside the `games` session, every row saying
# `~prj/games/` tells you nothing), so it collapses into the tilde itself.
# Aliases may also shorten nested paths: `~/projects/game-demos/foo` becomes
# `~demos/foo`, while its `gauntlet-demos` subtree becomes `~gdemo`.
# Add or rename an alias by editing the mapping; the longest match wins.
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

# Project paths that collapse into the tilde. Values are display names.
PATH_ALIASES = {
    "games": "games",
    "house": "house",
    "game-demos": "demos",
    "game-demos/gauntlet-demos": "gdemo",
}

def pretty(path):
    if path == home:
        return "~"
    if path == home + "/projects":
        return "~prj"
    if path.startswith(home + "/projects/"):
        rest = path[len(home) + len("/projects/"):]
        for prefix in sorted(PATH_ALIASES, key=len, reverse=True):
            if rest == prefix:
                return "~" + PATH_ALIASES[prefix]
            if rest.startswith(prefix + "/"):
                return "~" + PATH_ALIASES[prefix] + rest[len(prefix):]
        return "~prj/" + rest
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

if [ "$WATCH" = 1 ]; then
    # One watcher per SESSION — the lock is keyed by name, so attaching the same
    # session twice still stacks up nothing, while a second session gets its own
    # watcher. mkdir is the atomic test-and-set that's portable to macOS, which
    # has no flock(1).
    lock="${TMPDIR:-/tmp}/herdr-cwd-labels.$SESSION.lock"

    # STALE LOCK RECOVERY: the EXIT trap cannot run on SIGKILL or a hard crash,
    # so the directory outlives its owner — and then this session's watcher would
    # decline to start forever, silently blanking the `$cwd` row with no error
    # anywhere. So the lock records its owner pid, and a lock whose owner is gone
    # is stolen rather than obeyed.
    if ! mkdir "$lock" 2>/dev/null; then
        owner=$(cat "$lock/pid" 2>/dev/null)
        if [ -z "$owner" ]; then
            # A lock with no pid file predates this recovery logic. Ask the
            # process table instead of assuming it is dead, or we would start a
            # second watcher alongside a perfectly healthy one.
            owner=$(pgrep -f -- "herdr-cwd-labels.sh --session $SESSION --watch" \
                    | grep -vx "$$" | head -1)
        fi
        if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
            exit 0                      # a live watcher already owns this session
        fi
        # Nothing alive owns it. Prefer stealing to obeying: a duplicate watcher
        # only writes the same token twice, whereas honouring a dead lock blanks
        # the row for as long as the file survives.
        # Stale. rmdir (not rm -rf) so a surprise non-empty lock is never blown
        # away; re-mkdir so two racing stealers cannot both win.
        rm -f "$lock/pid" 2>/dev/null
        rmdir "$lock" 2>/dev/null
        mkdir "$lock" 2>/dev/null || exit 0
    fi
    printf '%s\n' "$$" > "$lock/pid" 2>/dev/null

    # The INT/TERM handler MUST exit. A bare `trap 'rmdir ...' EXIT INT TERM`
    # (what this used to be) releases the lock and then lets bash RESUME the
    # loop, so the watcher survived `kill` while no longer holding its lock —
    # which let a second watcher start and double-publish. Verified 2026-07-26:
    # a TERMed watcher was still polling minutes later.
    cleanup() { rm -f "$lock/pid" 2>/dev/null; rmdir "$lock" 2>/dev/null; }
    trap cleanup EXIT
    trap 'cleanup; exit 0' INT TERM

    while herdr api snapshot >/dev/null 2>&1; do
        publish_once
        sleep "$INTERVAL"
    done
    exit 0
fi

publish_once
