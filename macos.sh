#!/usr/bin/env bash
#
# macOS new-machine setup — the macOS counterpart to install.sh + ubuntu.sh.
#
#   bash macos.sh                 # everything: short setup + headless half
#   bash macos.sh --short-setup   # ONLY the interactive parts (prompts /
#                                 #   password / sudo): Xcode CLT, git
#                                 #   identity, Homebrew, login shell,
#                                 #   sudo-needing casks
#   bash macos-headless.sh        # ONLY the unattended parts — safe for an
#                                 #   agent to run; see that file
#
# Ordering: --short-setup must run once before the headless half (Homebrew's
# installer requires sudo). Everything is idempotent — re-run any script any
# time; work already done is skipped, so mixing the two halves never
# duplicates work.
set -e

if [ "$(uname -s)" != "Darwin" ]; then
    echo "macos.sh is for macOS only — on Ubuntu use install.sh + ubuntu.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

short_setup() {
    echo ""
    echo "Short setup (interactive): Xcode CLT, git identity, Homebrew, login shell, sudo casks"

    echo ""
    echo "Checking Xcode Command Line Tools"

    if ( xcode-select -p 1>/dev/null 2>/dev/null ); then
        echo " - Already installed Xcode Command Line Tools"
    else
        echo " - Fetching Xcode Command Line Tools (accept the GUI prompt, then re-run macos.sh)"
        xcode-select --install
        exit 1
    fi

    # Prompt for identity here so the headless half never has to prompt.
    # Same flow as install.sh: identity lives in gitconfig + gitignored
    # ~/.extra, never in the repo.
    echo ""
    echo "Configuring git email & name"

    if ( ! git config --global user.email 1>/dev/null ); then
        echo " - Setting global user.email"
        read -p "Please enter email: " email
        git config --global user.email "$email"
    fi

    if ( ! git config --global user.name 1>/dev/null ); then
        echo " - Setting global user.name"
        read -p "Please enter username: " username
        git config --global user.name "$username"
    fi

    echo ""
    echo "Checking Homebrew"

    if ( hash brew 2>/dev/null ); then
        echo " - Already installed Homebrew"
    else
        echo " - Fetching Homebrew (will ask for your password)"
        # Download to a file, not $(curl ...) — a failed curl in a command
        # substitution runs `bash -c ""`, which succeeds and set -e never fires.
        BREW_INSTALLER="$(mktemp -d)/install.sh"
        if ! curl -fsSL -o "$BREW_INSTALLER" https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh; then
            # raw.githubusercontent.com rate-limits (HTTP 429); github.com doesn't.
            echo " - raw.githubusercontent.com failed; cloning Homebrew/install instead"
            BREW_INSTALLER_DIR="$(mktemp -d)"
            git clone --depth 1 https://github.com/Homebrew/install "$BREW_INSTALLER_DIR"
            BREW_INSTALLER="$BREW_INSTALLER_DIR/install.sh"
        fi
        /bin/bash "$BREW_INSTALLER"
    fi

    # Make brew available in THIS shell even before .bashrc/.zprofile exist.
    # /opt/homebrew on Apple Silicon, /usr/local on Intel.
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    echo ""
    echo "Checking login shell (Homebrew bash)"

    # Just the bash formula here — the full Brewfile runs in the headless half.
    BREW_BASH="$(brew --prefix)/bin/bash"
    if [ ! -x "$BREW_BASH" ]; then
        echo " - Installing Homebrew bash"
        brew install bash
    else
        echo " - Already installed Homebrew bash"
    fi
    if ! grep -q "$BREW_BASH" /etc/shells 2>/dev/null; then
        echo " - Adding $BREW_BASH to /etc/shells (needs sudo)"
        echo "$BREW_BASH" | sudo tee -a /etc/shells >/dev/null
    else
        echo " - Already listed in /etc/shells"
    fi
    if [ "$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')" = "$BREW_BASH" ]; then
        echo " - Already using Homebrew bash as login shell"
    else
        echo " - Switching login shell to $BREW_BASH (may prompt for your password)"
        chsh -s "$BREW_BASH"
    fi

    echo ""
    echo "Checking casks that need sudo"

    # These casks run privileged installers, so brew stops to ask for a
    # password — they would stall the headless half's brew bundle. Install
    # them here instead; brew bundle then sees them as already installed.
    # --adopt takes over app copies an MDM may have pre-seeded in /Applications.
    SUDO_CASKS="docker-desktop google-chrome slack zoom google-drive tailscale-app"
    MISSING_CASKS=""
    for cask in $SUDO_CASKS; do
        if ! brew list --cask "$cask" 1>/dev/null 2>/dev/null; then
            MISSING_CASKS="$MISSING_CASKS $cask"
        fi
    done
    if [ -n "$MISSING_CASKS" ]; then
        echo " - Installing (will ask for your password):$MISSING_CASKS"
        # One at a time, warn-and-continue — a single broken installer
        # must not abort the whole setup.
        FAILED_CASKS=""
        for cask in $MISSING_CASKS; do
            brew install --cask --adopt "$cask" || FAILED_CASKS="$FAILED_CASKS $cask"
        done
        if [ -n "$FAILED_CASKS" ]; then
            echo "warn: casks failed, install manually or re-run:$FAILED_CASKS"
        fi
    else
        echo " - Already installed"
    fi

    echo ""
    echo "Short setup done. Remainder: bash macos-headless.sh (no prompts, agent-safe)"
}

case "${1:-}" in
    --short-setup|short-setup)
        short_setup
        ;;
    "")
        short_setup
        bash "$SCRIPT_DIR/macos-headless.sh"
        ;;
    *)
        echo "Usage: bash macos.sh [--short-setup]"
        echo "  (none)         everything: short setup, then macos-headless.sh"
        echo "  --short-setup  only the interactive parts (prompts/password/sudo)"
        exit 1
        ;;
esac
