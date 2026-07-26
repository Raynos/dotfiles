#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE}")"
git pull origin master
# NOTE: .config/herdr/ is excluded because it is symlink-managed by
# .config/install.sh, not copy-managed. rsync transfers a regular file by renaming
# a temp into place, which would replace ~/.config/herdr/config.toml (a symlink
# back into this repo) with a real copy — silently un-tracking it and
# reintroducing drift. Run ./.config/install.sh instead.
#
# Deliberately scoped to herdr, NOT all of .config/: .config/terminator/config is
# still copy-managed and must keep being rsynced. ("install.sh" below is
# unanchored, so it already keeps .config/install.sh out of ~.)
function doIt() {
	rsync --exclude ".git/" \
    --exclude ".gitignore" \
    --exclude ".DS_Store" \
    --exclude ".config/herdr/" \
    --exclude "bootstrap.sh" \
    --exclude "README.md" \
    --exclude "init.sh" \
    --exclude "install.sh" \
    --exclude "sync-sublime.sh" \
    --exclude "projects.sh" \
    --exclude "ubuntu.sh" \
    --exclude "ubuntu-wallpaper.jpg" \
    -av --no-perms . ~
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
unset doIt
source ~/.bash_profile
