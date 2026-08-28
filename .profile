# POSIX login shells only — bash reads .bash_profile instead, zsh .zprofile.

[ -d /opt/homebrew/bin ] && export PATH="/opt/homebrew/bin:$PATH"
[ -d /opt/homebrew/opt/libpq/bin ] && export PATH="$PATH:/opt/homebrew/opt/libpq/bin"

export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
elif [ -s /opt/homebrew/opt/nvm/nvm.sh ]; then
  . /opt/homebrew/opt/nvm/nvm.sh
fi
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# See .exports — non-interactive/login shells that never source .bashrc still
# want node's V8 compile cache. Kept under the OS temp dir so stale entries are
# reaped for us; see the long note there.
if [ -n "$TMPDIR" ]; then
    export NODE_COMPILE_CACHE="${TMPDIR%/}/node-compile-cache"
else
    export NODE_COMPILE_CACHE="/tmp/node-compile-cache-$(id -u)"
fi
