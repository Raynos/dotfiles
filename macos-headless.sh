#!/usr/bin/env bash
#
# macOS setup, headless half — every step that needs NO prompts, NO password,
# NO sudo. Safe for an agent or CI to run unattended. Idempotent — re-run any
# time; anything already done is skipped.
#
# Prereq: `bash macos.sh --short-setup` (interactive: Xcode CLT, Homebrew,
# login shell) must have run once first. `bash macos.sh` runs both halves.
#
# Usage: bash macos-headless.sh
set -e

if [ "$(uname -s)" != "Darwin" ]; then
    echo "macos-headless.sh is for macOS only — on Ubuntu use install.sh + ubuntu.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make brew available in THIS shell even before .bashrc/.zprofile exist.
# /opt/homebrew on Apple Silicon, /usr/local on Intel.
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

if ! ( hash brew 2>/dev/null ); then
    echo "error: Homebrew not installed — run 'bash macos.sh --short-setup' first (needs your password)"
    exit 1
fi

echo ""
echo "Checking ~/projects and ~/bin"

mkdir -p ~/projects ~/bin
if [ ! -e ~/.extra ]; then
    touch ~/.extra
fi

# .bash_prompt shows "production" (all-yellow) colors unless this is exactly
# the string 1 — seed it on personal machines so the local palette applies.
if ! grep -q 'IS_LOCAL_MACHINE' ~/.extra; then
    echo " - Storing IS_LOCAL_MACHINE=1 in ~/.extra (local prompt colors)"
    echo 'export IS_LOCAL_MACHINE=1' >> ~/.extra
fi

echo ""
echo "Checking git email & name"

# Identity is PROMPTED in macos.sh --short-setup; here we only mirror an
# already-set identity into gitignored ~/.extra, never prompt.
if ( git config --global user.email 1>/dev/null ); then
    if ( ! grep 'git config --global user.email' 1>/dev/null 2>/dev/null ~/.extra ); then
        echo " - Storing global user.email in ~/.extra"
        echo "git config --global user.email '$(git config --global user.email)'" >> ~/.extra
    fi
else
    echo " - warn: git user.email not set; run 'bash macos.sh --short-setup' to be prompted"
fi

if ( git config --global user.name 1>/dev/null ); then
    if ( ! grep 'git config --global user.name' 1>/dev/null 2>/dev/null ~/.extra ); then
        echo " - Storing global user.name in ~/.extra"
        echo "git config --global user.name '$(git config --global user.name)'" >> ~/.extra
    fi
else
    echo " - warn: git user.name not set; run 'bash macos.sh --short-setup' to be prompted"
fi

echo ""
echo "Installing Brewfile bundle (formulae + casks)"
# Homebrew 6+ refuses formulae from untrusted third-party taps; trust the
# Brewfile's taps up front (idempotent, no-op on older Homebrew).
if brew trust --help 1>/dev/null 2>/dev/null; then
    brew trust hashicorp/tap depot/tap francium-tech/tap ykushch/tap
fi
# brew bundle exits non-zero when the sudo-needing casks (SUDO_CASKS in
# macos.sh) hit a password prompt this shell can't answer — expected here;
# `bash macos.sh --short-setup` installs those. Warn and keep going so the
# rest of the headless setup still runs; failures stay visible above.
brew bundle --file="$SCRIPT_DIR/Brewfile" || \
    echo "warn: brew bundle reported failures above — if they are only the sudo casks, run 'bash macos.sh --short-setup' to install them"

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
echo "Checking pnpm"

if ( hash pnpm 2>/dev/null ); then
    echo " - Already installed pnpm"
elif ( hash npm 2>/dev/null ); then
    echo " - Installing pnpm (npm -g)"
    npm install -g pnpm
else
    echo " - warn: npm not found (node install failed above?); skipping pnpm"
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
if ( hash claude 2>/dev/null ) || [ -x ~/.local/bin/claude ]; then
    echo " - Already installed claude"
else
    echo " - Fetching claude"
    curl -fsSL https://claude.ai/install.sh | bash
fi

echo ""
echo "Checking cursor-agent CLI"

if ( hash cursor-agent 2>/dev/null ) || [ -x ~/.local/bin/cursor-agent ]; then
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
# Gallery view in Finder (icon view would be "icnv")
defaults write com.apple.finder FXPreferredViewStyle -string "glyv"
mkdir -p ~/Documents/Screenshots
defaults write com.apple.screencapture location -string "$HOME/Documents/Screenshots"

killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

echo ""
echo "Headless setup finished. Next steps:"
echo ""
echo "  1. source bootstrap.sh   # lay down dotfiles + run the per-tool installers"
echo ""
echo "Manual checklist (things a script can't do):"
echo "  - SSH key + commit signing (.gitconfig enforces SSH signing; commits FAIL without it):"
echo "      ssh-keygen -t ed25519 -C 'your-email'"
echo "      # allowed_signers needs ONE LINE PER COMMITTER EMAIL (personal + work),"
echo "      # or history signed under the other email shows as unverified:"
echo "      printf '%s namespaces=\"git\" %s\n' raynos2@gmail.com \"\$(cat ~/.ssh/id_ed25519.pub)\" >  ~/.ssh/allowed_signers"
echo "      printf '%s namespaces=\"git\" %s\n' jake@socket.dev  \"\$(cat ~/.ssh/id_ed25519.pub)\" >> ~/.ssh/allowed_signers"
echo "      chmod 600 ~/.ssh/allowed_signers"
echo "      # upload to GitHub as BOTH key types; default gh token lacks the scopes:"
echo "      gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key"
echo "      gh ssh-key add ~/.ssh/id_ed25519.pub --type authentication"
echo "      gh ssh-key add ~/.ssh/id_ed25519.pub --type signing"
echo "  - Clone the private work repo and run its installer (provides the"
echo "    ~/.cursor skills/rules/hooks symlinks + hooks.json — dotfiles does NOT):"
echo "      gh repo clone Raynos/work-skills ~/projects/work-skills && ~/projects/work-skills/install.sh"
echo "  - Launch Codex.app once and sign in — that materializes the openai-bundled"
echo "    plugin marketplace; codex/install.sh reports browser@openai-bundled missing until then"
echo "  - Sign in: iCloud / App Store, 1Password, Google, Slack, gcloud auth login"
echo "  - Grant permissions (System Settings > Privacy & Security):"
echo "      Accessibility: iTerm, AltTab, Docker; Screen Recording: zoom"
echo "  - Restart iTerm2 after bootstrap so it loads the versioned settings (iterm2/)"
echo "  - Docker Desktop first run (license prompt + starts the daemon)"
echo "  - Dark mode / scroll direction take effect after logout"
