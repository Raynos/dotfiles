# Bash completion for the `claude` CLI (Claude Code).
#
# The claude CLI ships no completion generator, so the flag/subcommand lists are
# parsed out of `claude --help`. That call costs ~130ms, which is far too slow to
# sit on the TAB key, so it NEVER runs on the hot path:
#
#   * the lists live in shell variables, seeded from the baked-in snapshot below;
#   * a persistent cache (~/.cache/claude-completion/lists) overrides the
#     snapshot, and is read with builtins exactly once per shell;
#   * when that cache is missing or >1 day old, `claude --help` is re-run in the
#     BACKGROUND. The current TAB answers instantly from whatever it already has.
#
# So the worst case after a claude upgrade is one completion with day-old flags,
# instead of a 130ms stall on every dash-completion. Refresh by hand with
# `_claude_lists_refresh`; nuke the cache to fall back to the snapshot.
#
# Sourced from .bashrc alongside .git-completion.bash / .pnpm-completion.bash.

_CLAUDE_COMPLETION_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-completion/lists"

# Baked-in snapshot (claude 2.1.238) — used until the cache lands.
_CLAUDE_SUBCMDS='agents auth auto-mode doctor gateway import install mcp plugin project setup-token ultrareview update'
_CLAUDE_FLAGS='--add-dir --agent --agents --allow-dangerously-skip-permissions --allowed-tools --allowedTools --append-system-prompt --autocompact --ax-screen-reader --background --bare --betas --bg --brief --chrome --cloud --continue --dangerously-skip-permissions --debug --debug-file --disable-slash-commands --disallowed-tools --disallowedTools --effort --environment --exclude-dynamic-system-prompt-sections --fallback-model --file --fork-session --forward-subagent-text --from-pr --help --ide --include-hook-events --include-partial-messages --input-format --json-schema --max-budget-usd --mcp-config --model --name --no-chrome --no-session-persistence --output-format --permission-mode --plugin-dir --plugin-url --print --prompt-suggestions --remote-control --remote-control-session-name-prefix --replay-user-messages --resume --safe-mode --session-id --setting-sources --settings --strict-mcp-config --system-prompt --teleport --tmux --tools --verbose --version --worktree'

_CLAUDE_LISTS_LOADED=   # per-shell latch: cache is consulted at most once

# Re-parse `claude --help` and rewrite the cache. Slow (~130ms); only ever
# called in the background, or by hand after an upgrade.
_claude_lists_refresh() {
    local help subs flags dir tmp
    help=$(command claude --help 2>/dev/null) || return 1
    subs=$(printf '%s\n' "$help" | sed -n '/^Commands:/,$p' \
        | grep -oE '^  [a-z][a-z0-9-]*' | tr -d ' ' | sort -u | tr '\n' ' ')
    flags=$(printf '%s\n' "$help" \
        | grep -oE -- '--[a-zA-Z][a-zA-Z0-9-]*' | sort -u | tr '\n' ' ')
    [[ -n $flags ]] || return 1

    dir=${_CLAUDE_COMPLETION_CACHE%/*}
    mkdir -p "$dir" 2>/dev/null || return 1
    tmp="$_CLAUDE_COMPLETION_CACHE.$$"
    if printf '%s\n%s\n%s\n' "$EPOCHSECONDS" "$subs" "$flags" > "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$_CLAUDE_COMPLETION_CACHE" 2>/dev/null
    fi
    rm -f "$tmp" 2>/dev/null
}

# Fork-free: three builtin reads off one file descriptor, no cat/find/subshell.
_claude_lists_load() {
    [[ -n $_CLAUDE_LISTS_LOADED ]] && return 0
    _CLAUDE_LISTS_LOADED=1

    local stamp subs flags
    # `2>/dev/null` must precede the input redirect: redirections are applied
    # left to right, and a missing cache file is a *redirection* error.
    if { read -r stamp && read -r subs && read -r flags; } \
            2>/dev/null < "$_CLAUDE_COMPLETION_CACHE"; then
        [[ -n $subs ]] && _CLAUDE_SUBCMDS=$subs
        [[ -n $flags ]] && _CLAUDE_FLAGS=$flags
    fi
    [[ $stamp =~ ^[0-9]+$ ]] || stamp=0

    if (( EPOCHSECONDS - stamp > 86400 )); then
        # Detached so the pending TAB never waits on it; braces + disown keep
        # job-control chatter out of the prompt.
        { _claude_lists_refresh >/dev/null 2>&1 & } 2>/dev/null
        disown $! 2>/dev/null
    fi
    return 0
}

_claude_complete() {
    local cur prev
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}
    _claude_lists_load

    # Values for the flags where a filename is the wrong guess.
    case $prev in
        --model|--fallback-model)
            COMPREPLY=( $(compgen -W 'default opus sonnet haiku fable claude-opus-5 claude-sonnet-5 claude-fable-5 claude-haiku-4-5-20251001' -- "$cur") )
            return 0 ;;
        --effort)
            COMPREPLY=( $(compgen -W 'low medium high xhigh max' -- "$cur") )
            return 0 ;;
        --permission-mode)
            COMPREPLY=( $(compgen -W 'default acceptEdits plan bypassPermissions' -- "$cur") )
            return 0 ;;
        --output-format)
            COMPREPLY=( $(compgen -W 'text json stream-json' -- "$cur") )
            return 0 ;;
        --input-format)
            COMPREPLY=( $(compgen -W 'text stream-json' -- "$cur") )
            return 0 ;;
        --add-dir|--plugin-dir)
            # Scoped here rather than on `complete`: as a global option it also
            # stats word-list candidates, so a local ./agents dir would render
            # the `agents` subcommand as `agents/`.
            compopt -o filenames 2>/dev/null
            COMPREPLY=( $(compgen -d -- "$cur") )
            return 0 ;;
    esac

    # Subcommand right after `claude`
    if [[ $COMP_CWORD -eq 1 && $cur != -* ]]; then
        COMPREPLY=( $(compgen -W "$_CLAUDE_SUBCMDS" -- "$cur") )
        return 0
    fi

    # Flags whenever the current word starts with a dash
    if [[ $cur == -* ]]; then
        COMPREPLY=( $(compgen -W "$_CLAUDE_FLAGS" -- "$cur") )
        return 0
    fi

    # Anything else: leave COMPREPLY empty so `-o default -o bashdefault` hand
    # off to bash's own filename completion, which (unlike a hand-rolled
    # `compgen -f`) expands ~, honours quoting, and marks directories.
    return 0
}

# Bash keys completion off the word as typed, so the `claude-personal` wrapper
# (personal profile; see .bashrc) needs its own registration.
complete -o default -o bashdefault -F _claude_complete claude claude-personal
