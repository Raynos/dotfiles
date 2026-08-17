#!/usr/bin/env bash
#
# macOS new-machine setup — the macOS counterpart to install.sh + ubuntu.sh.
#
# Provisions a fresh Mac: Xcode CLT, Homebrew, everything in ./Brewfile,
# login shell, node via nvm, AI CLIs, and macOS defaults. Idempotent —
# re-run any time. Run this FIRST, then `source bootstrap.sh` to lay down
# the dotfiles.
#
# Usage: bash macos.sh
set -e

if [ "$(uname -s)" != "Darwin" ]; then
    echo "macos.sh is for macOS only — on Ubuntu use install.sh + ubuntu.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Checking Xcode Command Line Tools"

if ( xcode-select -p 1>/dev/null 2>/dev/null ); then
    echo " - Already installed Xcode Command Line Tools"
else
    echo " - Fetching Xcode Command Line Tools (accept the GUI prompt, then re-run macos.sh)"
    xcode-select --install
    exit 1
fi

echo ""
echo "Checking Homebrew"

if ( hash brew 2>/dev/null ); then
    echo " - Already installed Homebrew"
else
    echo " - Fetching Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make brew available in THIS shell even before .bashrc/.zprofile exist.
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo ""
echo "Installing Brewfile bundle (formulae + casks)"
brew bundle --file="$SCRIPT_DIR/Brewfile"

echo ""
echo "Checking login shell (Homebrew bash)"

BREW_BASH="$(brew --prefix)/bin/bash"
if ! grep -q "$BREW_BASH" /etc/shells 2>/dev/null; then
    echo " - Adding $BREW_BASH to /etc/shells (needs sudo)"
    echo "$BREW_BASH" | sudo tee -a /etc/shells >/dev/null
fi
if [ "$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')" = "$BREW_BASH" ]; then
    echo " - Already using Homebrew bash as login shell"
else
    echo " - Switching login shell to $BREW_BASH"
    chsh -s "$BREW_BASH"
fi

echo ""
echo "Checking ~/projects and ~/bin"

if [ ! -e ~/projects ]; then
    mkdir ~/projects
fi
if [ ! -e ~/bin ]; then
    mkdir ~/bin
fi
if [ ! -e ~/.extra ]; then
    touch ~/.extra
fi

echo ""
echo "Configuring git email & name"

# Same flow as install.sh: identity lives in gitconfig + gitignored ~/.extra,
# never in the repo.
if ( ! git config --global user.email 1>/dev/null ); then
    echo " - Setting global user.email"
    read -p "Please enter email: " email
    git config --global user.email "$email"
fi

if ( ! grep 'git config --global user.email' 1>/dev/null 2>/dev/null ~/.extra ); then
    echo " - Storing global user.email in ~/.extra"
    echo "git config --global user.email '$(git config --global user.email)'" >> ~/.extra
fi

if ( ! git config --global user.name 1>/dev/null ); then
    echo " - Setting global user.name"
    read -p "Please enter username: " username
    git config --global user.name "$username"
fi

if ( ! grep 'git config --global user.name' 1>/dev/null 2>/dev/null ~/.extra ); then
    echo " - Storing global user.name in ~/.extra"
    echo "git config --global user.name '$(git config --global user.name)'" >> ~/.extra
fi

echo ""
echo "Checking node (nvm)"

# brew's nvm keeps versions in ~/.nvm and its loader script in the prefix.
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"
if [ -s "$(brew --prefix nvm)/nvm.sh" ]; then
    . "$(brew --prefix nvm)/nvm.sh"
    if ( hash node 2>/dev/null ); then
        echo " - Already installed node $(node -v)"
    else
        echo " - Fetching node (latest LTS)"
        nvm install --lts
        nvm alias default 'lts/*'
    fi
else
    echo " - warn: nvm not found under brew prefix; skipping node install"
fi

echo ""
echo "Checking rupa/z"

if [ ! -e ~/projects/z ]; then
    echo " - Fetching rupa/z"
    git clone https://github.com/rupa/z ~/projects/z
else
    echo " - Already installed rupa/z"
fi

echo ""
echo "Checking claude CLI"

# Native installer, versioned under ~/.local — separate from the Claude.app cask.
if ( hash claude 2>/dev/null ); then
    echo " - Already installed claude"
else
    echo " - Fetching claude"
    curl -fsSL https://claude.ai/install.sh | bash
fi

echo ""
echo "Checking cursor-agent CLI"

if ( hash cursor-agent 2>/dev/null ); then
    echo " - Already installed cursor-agent"
else
    echo " - Fetching cursor-agent"
    curl -fsS https://cursor.com/install | bash
fi

# codex (app + CLI) comes from the Brewfile cask.

echo ""
echo "Writing macOS defaults"

defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool true
# "Natural" scrolling off
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
defaults write com.apple.dock tilesize -int 72
defaults write com.apple.finder ShowPathbar -bool true
# Icon view in Finder
defaults write com.apple.finder FXPreferredViewStyle -string "glyv"
mkdir -p ~/Documents/Screenshots
defaults write com.apple.screencapture location -string "$HOME/Documents/Screenshots"

killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

echo ""
echo "All finished. Next steps:"
echo ""
echo "  1. source bootstrap.sh   # lay down dotfiles + run the per-tool installers"
echo ""
echo "Manual checklist (things a script can't do):"
echo "  - SSH key + commit signing (.gitconfig enforces SSH signing; commits FAIL without it):"
echo "      ssh-keygen -t ed25519 -C 'your-email'"
echo "      echo \"your-email namespaces=\\\"git\\\" \$(cat ~/.ssh/id_ed25519.pub)\" > ~/.ssh/allowed_signers"
echo "      pbcopy < ~/.ssh/id_ed25519.pub   # add to GitHub as BOTH auth and signing key"
echo "  - Sign in: iCloud / App Store, 1Password, Google, Slack, gcloud auth login"
echo "  - Grant permissions (System Settings > Privacy & Security):"
echo "      Accessibility: iTerm, AltTab, Docker; Screen Recording: Loom, zoom"
echo "  - iTerm2 profiles: create 'Default', 'Vibe', 'House' (bin/herdr-attach switches between them)"
echo "  - Docker Desktop first run (license prompt + starts the daemon)"
echo "  - Dark mode / scroll direction take effect after logout"
