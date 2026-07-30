#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE}")"
git pull origin master
# NOTE: .config/herdr/ is excluded because it is symlink-managed by
# .config/install.sh, not copy-managed. rsync transfers a regular file by renaming
# a temp into place, which would replace ~/.config/herdr/config.toml (a symlink
# back into this repo) with a real copy — silently un-tracking it and
# reintroducing drift. Run ./.config/install.sh instead.
#
# pnpm/ is excluded for the same reason: pnpm/install.sh symlinks the managed
# global rc into pnpm's globalconfig path (Library/Preferences on macOS).
#
# Deliberately scoped to herdr, NOT all of .config/: .config/terminator/config is
# still copy-managed and must keep being rsynced. ("install.sh" below is
# unanchored, so it already keeps .config/install.sh out of ~.)
function doIt() {
	rsync --exclude ".git/" \
    --exclude ".gitignore" \
    --exclude ".DS_Store" \
    --exclude ".config/herdr/" \
    --exclude "pnpm/" \
    --exclude "bootstrap.sh" \
    --exclude "README.md" \
    --exclude "init.sh" \
    --exclude "install.sh" \
    --exclude "sync-sublime.sh" \
    --exclude "projects.sh" \
    --exclude "ubuntu.sh" \
    --exclude "ubuntu-wallpaper.jpg" \
    -av --no-perms . ~

	runInstallers
}

# rsync only copies files into ~. It cannot create the symlinks into ~/.claude,
# ~/.codex and ~/.config, merge the managed subset of settings.json, or sync
# plugins — that is what the per-tool installers do. Nothing used to call them,
# so a fresh machine following the README got every dotfile and none of the
# agent tooling, silently: no hooks, no statusline, no herdr config.
#
# Each installer is idempotent (they print "ok" for anything already linked), so
# re-running on every bootstrap is cheap. Failures are reported and stepped over
# rather than propagated, because bootstrap.sh is meant to be SOURCED — an
# unguarded non-zero exit out of a `set -e` installer would kill the
# interactive shell that sourced this.
function runInstallers() {
	local installer
	for installer in .config/install.sh claude/install.sh codex/install.sh agents/install.sh pnpm/install.sh; do
		if [ ! -x "$installer" ]; then
			echo "skip (not executable): $installer"
			continue
		fi
		echo ""
		echo "Running $installer"
		if ! "./$installer"; then
			echo "warn: $installer failed — continuing"
		fi
	done
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	doIt
else
	read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		doIt
	fi
fi
unset doIt runInstallers
source ~/.bash_profile
