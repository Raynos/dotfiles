# POSIX login shells only — bash reads .bash_profile instead, zsh .zprofile.

[ -d /opt/homebrew/bin ] && export PATH="/opt/homebrew/bin:$PATH"
[ -d /opt/homebrew/opt/libpq/bin ] && export PATH="$PATH:/opt/homebrew/opt/libpq/bin"

# See .path — POSIX login shells never source .bashrc, so they never reach the
# bun entry there. omp and every other globally-installed bun CLI needs this.
export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && export PATH="$BUN_INSTALL/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
elif [ -s /opt/homebrew/opt/nvm/nvm.sh ]; then
  . /opt/homebrew/opt/nvm/nvm.sh
fi
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# See .exports — non-interactive/login shells that never source .bashrc still
# want node's V8 compile cache. Kept out of $TMPDIR, which macOS empties at
# boot before login; see the note there (2026-10-15).
if [ "$(uname)" = Darwin ]; then
    export NODE_COMPILE_CACHE="$HOME/Library/Caches/node-compile-cache"
else
    export NODE_COMPILE_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/node-compile-cache"
fi
