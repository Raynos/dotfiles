# Brewfile — full mirror of my macOS machine, sectioned.
# Install with: brew bundle --file=Brewfile   (macos.sh does this)
#
# Machine-specific/company-managed software (MDM agents, corp security tooling,
# licensed fonts) is deliberately absent — IT provisions those.

# --- Taps -------------------------------------------------------------------
tap 'hashicorp/tap'
tap 'depot/tap'
# Homebrew 6+ treats ALL third-party taps as untrusted (depot/tap included);
# macos-headless.sh runs `brew trust` on every tap here before `brew bundle`.
tap 'francium-tech/tap'
tap 'ykushch/tap'

# --- Shell & core CLI -------------------------------------------------------
brew 'bash' # login shell (macos.sh runs chsh)
brew 'bat'
brew 'brightness'
brew 'cloc'
brew 'gh'
brew 'git-delta'
brew 'git-filter-repo'
brew 'git-lfs'
brew 'glow'
brew 'gnupg'
brew 'herdr'
brew 'htop'
brew 'jq'
brew 'ncdu'
brew 'ripgrep'
brew 'shellcheck'
brew 'tree'

# --- Languages & build ------------------------------------------------------
brew 'automake'
brew 'capnp'
brew 'cmake'
brew 'composer'
brew 'deno'
brew 'go'
brew 'nvm' # node itself comes from `nvm install` (macos.sh)
brew 'pyenv'
brew 'python-setuptools'
brew 'uv'

# --- Cloud & infra ----------------------------------------------------------
brew 'awscli'
brew 'depot/tap/depot'
brew 'hashicorp/tap/terraform'
brew 'helm'
brew 'jsonnet'
brew 'jsonnet-bundler'
brew 'kubernetes-cli'
brew 'kustomize'
brew 'rclone'
brew 'semgrep'
brew 'tanka'

# --- Databases --------------------------------------------------------------
brew 'libpq'
brew 'pgvector'
brew 'redis'

# --- Media & documents ------------------------------------------------------
brew 'cpdf'
brew 'ffmpeg'
brew 'francium-tech/tap/scanify'
brew 'graphviz'
brew 'imagemagick'
brew 'ocrmypdf'
brew 'oxipng'
brew 'poppler'
brew 'tesseract-lang'
brew 'whisper-cpp'
brew 'yt-dlp'
brew 'zopfli'

# --- Fun --------------------------------------------------------------------
brew 'sdl2_image'
brew 'sdl2_mixer'
brew 'sdl2_net'

# Casks whose installers need sudo (docker-desktop, google-chrome, slack,
# zoom, google-drive, tailscale-app) are pre-installed by
# `macos.sh --short-setup` so the headless `brew bundle` never hits a
# password prompt. Keep both lists in sync (SUDO_CASKS in macos.sh).

# --- Casks: dev essentials --------------------------------------------------
cask '1password-cli'
cask 'bruno'
cask 'claude' # Claude desktop app; the claude CLI is installed by macos.sh
cask 'codex' # OpenAI Codex CLI (despite the cask description, no .app)
# Codex desktop app — REQUIRED for browser@openai-bundled: the CLI alone never
# registers the openai-bundled plugin marketplace; launching + signing into the
# app materializes it. Deprecated upstream (replacement: chatgpt cask, disabled
# 2027-07-12) — revisit when it breaks.
cask 'codex-app'
cask 'cursor'
cask 'dbeaver-community'
cask 'docker-desktop'
cask 'gcloud-cli'
cask 'google-chrome'
cask 'iterm2'
cask 'linear'
cask 'ngrok'
cask 'notchagent'
cask 'notion'
cask 'pgadmin4'
cask 'slack'
cask 'zoom'

# --- Casks: utilities -------------------------------------------------------
cask 'alt-tab'
cask 'google-drive'
cask 'grandperspective'
cask 'libreoffice'
cask 'pdf-expert'
cask 'tailscale-app'
cask 'wispr-flow'

# --- Casks: personal --------------------------------------------------------
cask 'blender'
cask 'librecad'
cask 'signal'
cask 'sketchup'
cask 'spotify'
cask 'whatsapp'
