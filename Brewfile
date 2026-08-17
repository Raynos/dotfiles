# Brewfile — full mirror of my macOS machine, sectioned.
# Install with: brew bundle --file=Brewfile   (macos.sh does this)
#
# Machine-specific/company-managed software (MDM agents, corp security tooling,
# licensed fonts) is deliberately absent — IT provisions those.

# --- Taps -------------------------------------------------------------------
tap 'hashicorp/tap'
tap 'depot/tap'
# Newer Homebrew treats third-party taps as untrusted; if `brew bundle` balks,
# run: brew trust francium-tech/tap ykushch/tap
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
brew 'mgba'
brew 'sdl2_image'
brew 'sdl2_mixer'
brew 'sdl2_net'

# --- Casks: dev essentials --------------------------------------------------
cask '1password-cli'
cask 'bruno'
cask 'claude' # Claude desktop app; the claude CLI is installed by macos.sh
cask 'codex' # OpenAI Codex (app + CLI)
cask 'cursor'
cask 'dbeaver-community'
cask 'docker-desktop'
cask 'gcloud-cli'
cask 'google-chrome'
cask 'iterm2'
cask 'linear-linear'
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
cask 'expressvpn'
cask 'librecad'
cask 'signal'
cask 'sketchup'
cask 'spotify'
cask 'whatsapp'
