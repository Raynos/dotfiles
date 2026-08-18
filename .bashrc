set +h


[[ $- == *i* ]] || return 0


# Core please
ulimit -c unlimited

# Run nvm so that it's accessible
if [ -e ~/projects/nvm ]; then
    . ~/projects/nvm/nvm.sh
    node_version=${NVM_NODE_VERSION:-"v16.17.0"}
    # Tell nvm to use the latest node 0.8 branch
    nvm use $node_version
elif [ -s /opt/homebrew/opt/nvm/nvm.sh ]; then
    # macOS: nvm comes from Homebrew (macos.sh), versions live in ~/.nvm
    export NVM_DIR="$HOME/.nvm"
    . /opt/homebrew/opt/nvm/nvm.sh
fi

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
source ~/.path
[[ $- == *i* ]] || return

# test if the prompt var is not set
if [ -z "$PS1" ]; then
    # prompt var is not set, so this is *not* an interactive shell
    return
fi

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{extra,bash_prompt,exports,aliases,functions}; do
    [ -r "$file" ] && source "$file"
done
unset file


# init z   https://github.com/rupa/z
if [ -e ~/projects/z ]; then
    . ~/projects/z/z.sh
fi

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

# Append to the Bash history file, rather than overwriting it
shopt -s histappend

# Autocorrect typos in path names when using `cd`
shopt -s cdspell

# Enable some Bash 4 features when possible:
# * Recursive globbing, e.g. `echo **/*.txt`
for option in globstar; do
    shopt -s "$option" 2> /dev/null
done

# Add tab completion for SSH hostnames based on ~/.ssh/config, ignoring wildcards
[ -e "$HOME/.ssh/config" ] && complete -o "default" -o "nospace" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2 | tr ' ' '\n')" scp sftp ssh

# If possible, add tab completion for many more commands
[ -f /etc/bash_completion ] && source /etc/bash_completion

# Add git-completion.bash
if [ -f ~/.git-completion.bash ]; then
  source ~/.git-completion.bash
fi

source ~/.pnpm-completion.bash

# Add npm tab completion (output of `npm completion`)
[ -f ~/.npm-completion.bash ] && source ~/.npm-completion.bash

# Add tab completion for the `claude` CLI (Claude Code)
[ -f ~/.claude-completion.bash ] && source ~/.claude-completion.bash

# Add tab completion for `herdr-attach` (session names come from its whitelist)
[ -f ~/.herdr-completion.bash ] && source ~/.herdr-completion.bash

# Add tab completion for the Codex CLI. The generated completion function
# understands wrappers because it keys off the command name passed by Bash.
if command -v codex >/dev/null 2>&1; then
  eval "$(command codex completion bash 2>/dev/null)"
  if declare -F _codex >/dev/null 2>&1; then
    complete -F _codex -o bashdefault -o default codex-personal
  fi
fi

# Detect which `ls` flavor is in use
if ls --color > /dev/null 2>&1; then
    colorflag="--color"
else
    colorflag="-G"
fi


# Always use color output for `ls`
alias ls="command ls ${colorflag}"
export LS_COLORS='no=00:fi=00:di=01;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:'

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
# pnpm >= 10 puts global bins in $PNPM_HOME/bin (older pnpm used $PNPM_HOME
# itself) — keep both on PATH or `pnpm add -g` binaries are unreachable.
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# ===== end personal-projects Codex guard =====

# ===== herdr auto-create guard =====
# Both `herdr --session <name>` and `herdr session attach <name>` auto-create on
# an unknown name, so a typo silently spawns a whole new session instead of
# failing. Route them through herdr-attach, which only ever attaches to a
# whitelisted name (and sets the matching iTerm profile). Everything else —
# `herdr session list`, `herdr status`, bare `herdr` — passes straight through.
# `command herdr` remains an explicit bypass, and is how you create a genuinely
# new session before adding it to the table in bin/herdr-attach.
alias herdr >/dev/null 2>&1 && unalias herdr
herdr() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --session|--session=*)
                printf '🚫 `herdr --session` auto-creates on typos — run `herdr-attach <name>` instead.\n' >&2
                return 1 ;;
        esac
    done

    if [ "${1:-}" = "session" ] && [ "${2:-}" = "attach" ]; then
        printf '🚫 `herdr session attach` auto-creates on typos — run `herdr-attach %s` instead.\n' "${3:-<name>}" >&2
        return 1
    fi

    command herdr "$@"
}
# ===== end herdr auto-create guard =====

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
[[ -r "$HOME/.grok/completions/bash/grok.bash" ]] && source "$HOME/.grok/completions/bash/grok.bash"
# <<< grok installer <<<
