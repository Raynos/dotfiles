# NOTE: this file used to start with `set +h`, which disables bash's command
# hash table. Without it every single command you run re-scans all ~45 PATH
# entries from scratch, and nvm's internal `hash -r` printed
# "bash: hash: hashing disabled" on every shell start. Hashing is on by design;
# anything that changes PATH (nvm included) already calls `hash -r` itself.


[[ $- == *i* ]] || return 0


# Core please
ulimit -c unlimited


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

# nvm goes last so its bin dir wins over Homebrew's node/npx shims.
# nvm, loaded LAZILY.
#
# Sourcing nvm.sh eagerly cost ~320ms per interactive shell: it is a 144KB
# script, and on load it runs `nvm use default`, which walks the tree looking
# for .nvmrc (forking `dirname` once per directory level, ~26 forks), shells out
# to `node --version` and `manpath`, and calls `hash -r`. Opening 20 shells at
# once meant 20x that, all competing for the same CPU and the same page cache.
#
# Instead: put the default version's bin dir on PATH directly (a file read plus
# a string prepend, ~0ms), which is all that 99% of shells ever need from nvm.
# The real nvm.sh is sourced on first use of `nvm`/`nvm_load`, and the stub
# functions below then get replaced by the genuine ones.
if [ -e ~/projects/nvm ]; then
    . ~/projects/nvm/nvm.sh
    node_version=${NVM_NODE_VERSION:-"v16.17.0"}
    # Tell nvm to use the latest node 0.8 branch
    nvm use $node_version
elif [ -s /opt/homebrew/opt/nvm/nvm.sh ]; then
    # macOS: nvm comes from Homebrew (macos.sh), versions live in ~/.nvm
    export NVM_DIR="$HOME/.nvm"

    # Resolve the `default` alias without running nvm. It may point at another
    # alias (`lts`, `node`) rather than a version, so follow the chain a couple
    # of hops before giving up and falling back to lazy-loading proper.
    __nvm_default_bin() {
        local alias_name=default hops=0 target
        while [ $hops -lt 4 ]; do
            [ -r "$NVM_DIR/alias/$alias_name" ] || return 1
            read -r target < "$NVM_DIR/alias/$alias_name" || return 1
            # nvm writes the alias either way ("24.18.1" or "v24.18.1"),
            # so normalise before looking for the version directory.
            case "$target" in
                v[0-9]*|[0-9]*)
                    [ "${target#v}" = "$target" ] && target="v$target"
                    [ -d "$NVM_DIR/versions/node/$target/bin" ] || return 1
                    printf '%s' "$NVM_DIR/versions/node/$target/bin"
                    return 0 ;;
                *) alias_name=$target; hops=$((hops + 1)) ;;
            esac
        done
        return 1
    }

    # Move it to the FRONT even if it is already present. A nested shell
    # inherits a PATH that already contains this dir somewhere in the middle; a
    # plain "add if missing" guard would leave it there, behind Homebrew's bin,
    # so `npx` (which Homebrew also ships) would resolve to the wrong node.
    if __nvm_bin=$(__nvm_default_bin); then
        local_path=":$PATH:"
        local_path="${local_path//:$__nvm_bin:/:}"
        local_path="${local_path#:}"
        local_path="${local_path%:}"
        export PATH="$__nvm_bin${local_path:+:$local_path}"
        unset local_path
    fi
    unset __nvm_bin
    unset -f __nvm_default_bin

    # First call to any of these pays the real load cost, once, in that shell.
    # nvm's own bash completion is loaded here too rather than at startup.
    nvm_load() {
        unset -f nvm nvm_load
        complete -r nvm 2>/dev/null
        . /opt/homebrew/opt/nvm/nvm.sh
        local c
        for c in "$NVM_DIR/bash_completion" \
                 /opt/homebrew/opt/nvm/etc/bash_completion.d/nvm; do
            [ -s "$c" ] && { . "$c"; break; }
        done
    }
    nvm() { nvm_load && nvm "$@"; }

    # Pressing Tab on `nvm ...` before nvm has ever been run loads it (and its
    # real completion), then hands off so the first Tab still completes.
    __nvm_lazy_complete() {
        nvm_load
        # nvm 0.40 registers __nvm; older versions used _nvm.
        local fn
        for fn in __nvm _nvm; do
            if declare -F "$fn" >/dev/null 2>&1; then
                "$fn" "$@"
                return
            fi
        done
    }
    complete -F __nvm_lazy_complete nvm
fi

# Collapse duplicate PATH entries.
#
# Every file above prepends unconditionally, and a login shell re-sources some
# of them, so PATH had grown to 45 entries with three copies of /opt/homebrew/bin
# and of the active node bin dir. Duplicates are not merely untidy: a command
# that misses the hash table is looked up by scanning PATH left to right, so
# every stale copy is extra filesystem work on every miss, in every shell.
# Keeps first occurrence (so precedence is unchanged) and drops the rest.
__dedupe_path() {
    local entry seen= out=
    local IFS=:
    for entry in $PATH; do
        [ -n "$entry" ] || continue
        case ":$seen:" in
            *":$entry:"*) continue ;;
        esac
        seen="${seen:+$seen:}$entry"
        out="${out:+$out:}$entry"
    done
    export PATH="$out"
}
__dedupe_path

