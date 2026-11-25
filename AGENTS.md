# AGENTS.md

 - Agents/claude/cursor/codex never edit AGENTS.md / 
    the root README.md, that's humans only.
 - Agents put proposed AGENTS.md changes in AGENTS_SUGGEST.md; 
    the human applies them and deletes it.

What this repo is

 - The real config files live here. Installers symlink them into ~,
     so edit here, never the ~ copy.
 - Each tool has a dir with its own install.sh (
    claude/, codex/, .config/, agents/, pnpm/ ...); bootstrap.sh runs them all.
 - Herdr app mods: .config/herdr-app/mods/. Reload one with: 
    rm ~/.config/herdr-app/mods/<name> && ./.config/install.sh
 - Herdr = the app (herdr-app) + herdr-core (hc); the old herdr TUI is gone.
    Setup notes for agents: .config/herdr-app/AGENTS.local.md.

Git hygiene

 - We commit early & often with git to main/master.
 - Push early & often ( every commit ).
 - Standardize the commit message style.

Shared checkout

 - Many agents work here, git add only for new files, use git commit -- <file>
 - Never git add -A / . / -u, never git commit -a, never bare git commit.
 - Never stash, checkout, restore or delete what you didn't author.

