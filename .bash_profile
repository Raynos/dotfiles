# (`set +h` used to be here — see the note at the top of ~/.bashrc for why
# disabling bash's command hash table was a bad idea on a 45-entry PATH.)

[[ $- == *i* ]] || return 0

# test if the prompt var is not set
if [ -z "$PS1" ]; then
    # prompt var is not set, so this is *not* an interactive shell
    return
fi

# Run the .bashrc
if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi

# .bashrc already deduped PATH, but this file appends after sourcing it (and an
# inherited PATH may already contain these). Run it once more, last.
declare -F __dedupe_path >/dev/null && __dedupe_path
