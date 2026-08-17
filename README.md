# Raynos dotfiles

Shell dotfiles plus per-tool installers (Claude Code, Codex, Cursor, herdr,
pnpm). The repo holds the real files; `bootstrap.sh` copies the classic
dotfiles into `~` and the installers symlink tool config back into the repo so
live edits flow straight into git.

## Installation

### Clone

```sh
mkdir -p ~/projects && cd ~/projects
git clone git@github.com:Raynos/dotfiles
cd dotfiles
git submodule init && git submodule update
```

## macOS

### Provision the machine

Installs Xcode CLT, Homebrew, everything in `Brewfile` (formulae + casks),
Homebrew bash as the login shell, node via nvm, the `claude` and
`cursor-agent` CLIs, and my macOS defaults. Idempotent — re-run any time.

```sh
bash macos.sh
```

It ends with a manual checklist for the things a script can't do (SSH key +
commit signing, app sign-ins, Privacy & Security permissions, iTerm2
profiles).

### Bootstrap the dotfiles

Copies the dotfiles into `~` and runs the per-tool installers
(`.config/`, `claude/`, `codex/`, `agents/`, `pnpm/`, `cursor/`):

```sh
source bootstrap.sh
```

## Ubuntu

### Fresh Clone

This will run the `init.sh` script in `bash` which will set up a fresh
ubuntu machine that doesn't have a copy of git installed yet.

```sh
wget -q -O - https://raw.githubusercontent.com/Raynos/dotfiles/master/init.sh 2>&1 | bash
# Add keys to github when prompted.
wget -q -O - https://raw.githubusercontent.com/Raynos/dotfiles/master/init.sh 2>&1 | bash
```

### Install (optional)

Installs dependencies via apt:

```sh
bash install.sh
```

### Ubuntu setup (optional)

Configures the GNOME/Unity GUI with better UI defaults:

```sh
bash ubuntu.sh
```

### Bootstrap

To copy all the files from `~/projects/dotfiles` into `~`:

```sh
source bootstrap.sh
```

## Local overrides

`~/.extra` (gitignored, sourced by `.bashrc`) holds anything you don't want
committed — git identity, machine-specific PATH entries, secrets.

## Thanks to…

 * Mathias Bynens for his dotfiles!
