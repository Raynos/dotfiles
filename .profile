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
