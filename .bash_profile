set +h

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

