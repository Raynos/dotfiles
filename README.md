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

On a fresh machine with no SSH keys yet, clone over HTTPS and rewrite the
SSH submodule URL (`.gitmodules` uses `git@github.com:`); flip the origin
remote back to SSH once keys exist:

```sh
git clone https://github.com/Raynos/dotfiles
cd dotfiles
git -c url."https://github.com/".insteadOf="git@github.com:" submodule update --init
# later, after ssh-keygen + GitHub key upload:
git remote set-url origin git@github.com:Raynos/dotfiles.git
```

## macOS

### Provision the machine

Installs Xcode CLT, Homebrew, everything in `Brewfile` (formulae + casks),
Homebrew bash as the login shell, node via nvm, the `claude` and
`cursor-agent` CLIs, and my macOS defaults. Idempotent — re-run any time.

```sh
bash macos.sh
```

Split for agent-driven setup: `--short-setup` runs only the interactive
parts (prompts / password / sudo — Xcode CLT, git identity, Homebrew, login
shell, and the casks whose installers need sudo), and `macos-headless.sh`
runs everything else with no prompts, so an
agent can run it unattended. Both halves skip work already done:

```sh
bash macos.sh --short-setup   # you, once, interactively
bash macos-headless.sh        # agent-safe remainder
```

It ends with a manual checklist for the things a script can't do (SSH key +
commit signing with a two-email `~/.ssh/allowed_signers`, app sign-ins,
Privacy & Security permissions, signing in to Codex.app to unlock its plugin
marketplace, and cloning the private `Raynos/work-skills` repo — that repo's
own installer provides the `~/.cursor` skills/rules/hooks symlinks and
`~/.cursor/hooks.json`, which this repo deliberately does not manage).

### Bootstrap the dotfiles

Copies the dotfiles into `~` and runs the per-tool installers
(`.config/`, `claude/`, `codex/`, `agents/`, `pnpm/`, `cursor/`, `iterm2/`):

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

`~/.extra` (gitignored, sourced by `.bashrc` *before* `.bash_prompt`, so it
can set flags the prompt reads) holds anything you don't want committed — git
identity, machine-specific PATH entries, secrets.

One load-bearing flag: `export IS_LOCAL_MACHINE=1` (the literal string `1`,
not `true`) switches `.bash_prompt` from the all-yellow "production" palette
to local colors. `macos-headless.sh` seeds it automatically.

## Thanks to…

 * Mathias Bynens for his dotfiles!
