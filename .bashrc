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
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Company machine default: naked `claude` uses company profile.
export CLAUDE_CONFIG_DIR="$HOME/.claude-company"
# `command claude` bypasses the games guard function below (which would
# otherwise block bare `claude`).
# ANTHROPIC_MODEL=opus pins every personal session to OPEN in Opus,
# regardless of what `/model` scribbles into ~/.claude/settings.json (the
# env var out-ranks the settings `model` key). Typing `/model fable` still
# switches the LIVE session fine — an explicit choice beats the env var —
# but the next session re-opens in Opus.
# Effort is handled DIFFERENTLY (no env var — that would hard-pin high and
# block runtime `/effort`). Instead we re-seed settings.json to "high" on
# every launch, so new sessions default to high while `/effort low` still
# works live and persists for the rest of that session.
unalias claude-personal 2>/dev/null  # else interactive alias-expansion breaks the def below
claude-personal() {
  local s="$HOME/.claude/settings.json"
  [ -f "$s" ] && jq '.effortLevel = "high"' "$s" > "$s.tmp" && mv "$s.tmp" "$s"
  ANTHROPIC_MODEL=opus CLAUDE_CONFIG_DIR="$HOME/.claude" command claude "$@"
}

# ===== personal-projects guard (added 2026-07-02) =====
# Block bare `claude` (company) under the personal project roots below and
# nudge toward claude-personal; delegate to your normal claude everywhere else.
# Placed at end of file so it wraps the claude defined above. Delete this
# block to remove. If your company `claude` is an *alias* (not a function),
# tell Claude Code so delegation can preserve its flags.
if declare -F claude >/dev/null 2>&1 && ! declare -F __claude_real >/dev/null 2>&1; then
    eval "__claude_real() $(declare -f claude | tail -n +2)"   # preserve company claude
fi
alias claude >/dev/null 2>&1 && unalias claude                 # step aside if it's an alias
claude() {
    case "$PWD/" in
        "$HOME/projects/games/"*|"$HOME/projects/house/"*|"$HOME/projects/personal/"*)
            printf '🚫 personal project — run `claude-personal` here, not company claude.\n' >&2
            return 1 ;;
    esac
    if declare -F __claude_real >/dev/null 2>&1; then __claude_real "$@"; else command claude "$@"; fi
}
# ===== end personal-projects guard =====

# Company machine default: naked `codex` uses the company profile. CODEX_HOME
# keeps config, auth, logs, sessions, and skills separate from the personal
# profile. Both directories must exist before Codex starts.
export CODEX_HOME="$HOME/.codex-company"
unalias codex-personal 2>/dev/null
codex-personal() {
    CODEX_HOME="$HOME/.codex" command codex "$@"
}

# ===== personal-projects Codex guard =====
# Match the Claude guard above: never accidentally open company Codex inside a
# personal checkout. `command codex` remains an explicit bypass.
alias codex >/dev/null 2>&1 && unalias codex
codex() {
    case "$PWD/" in
        "$HOME/projects/games/"*|"$HOME/projects/house/"*|"$HOME/projects/personal/"*)
            printf '🚫 personal project — run `codex-personal` here, not company codex.\n' >&2
            return 1 ;;
    esac
    command codex "$@"
}
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
