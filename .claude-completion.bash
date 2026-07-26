# Bash completion for the `claude` CLI (Claude Code).
#
# The claude CLI ships no completion generator, so this parses flags straight
# from `claude --help` and caches them (refreshed when the cache is >1 day old,
# so new flags appear after an upgrade). Subcommands are completed at position 1.
#
# Sourced from .bashrc alongside .git-completion.bash / .pnpm-completion.bash.

_claude_complete() {
    local cur prev cache subcmds
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    subcmds="agents auth auto-mode doctor gateway install mcp plugin project setup-token ultrareview update"

    # Complete a subcommand right after `claude`
    if [[ $COMP_CWORD -eq 1 && "$cur" != -* ]]; then
        COMPREPLY=( $(compgen -W "$subcmds" -- "$cur") )
        return 0
    fi

    # Complete flags whenever the current word starts with a dash
    if [[ "$cur" == -* ]]; then
        cache="${TMPDIR:-/tmp}/.claude_flags_cache"
        if [[ ! -f "$cache" || -n "$(find "$cache" -mtime +1 2>/dev/null)" ]]; then
            command claude --help 2>/dev/null \
                | grep -oE -- '--[a-zA-Z][a-zA-Z0-9-]*' \
                | sort -u > "$cache"
        fi
        COMPREPLY=( $(compgen -W "$(cat "$cache")" -- "$cur") )
        return 0
    fi

    # Otherwise fall back to filename completion (paths, prompts-from-file, etc.)
    COMPREPLY=( $(compgen -f -- "$cur") )
}
complete -F _claude_complete claude
# Same completion for the `claude-personal` alias (personal profile; see ~/.extra).
# Bash keys completion off the word as typed, so the alias needs its own registration.
complete -F _claude_complete claude-personal
