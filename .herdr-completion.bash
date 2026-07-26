# Tab completion for herdr-attach. Pulls the names from the script itself
# (`--list`) so the whitelist stays a single source of truth in bin/herdr-attach.
_herdr_attach_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"

    # Only the first argument is a session name.
    if [ "$COMP_CWORD" -ne 1 ]; then
        return 0
    fi

    COMPREPLY=($(compgen -W "$(herdr-attach --list 2>/dev/null)" -- "$cur"))
}

if command -v herdr-attach >/dev/null 2>&1; then
    complete -F _herdr_attach_complete herdr-attach
fi
