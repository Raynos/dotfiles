# This setup (Jake's)

Kept in `~/projects/dotfiles/.config/herdr-app/AGENTS.local.md` and linked
here by `.config/install.sh`. Edit the repo copy and commit it.

## Machines

- **MacBook** runs the window (`herdr-app`) and its own herdr-core.
- **Mac mini** (`mini`, `ssh mini`) runs herdr-core only. The MacBook's
  window reaches it over SSH, so `herdr-app` commands fail on the mini (no
  window socket); that is expected. Use `hc` there, or `hc --on mini ...`.

## Ours vs shipped

These are symlinks into `~/projects/dotfiles/.config/herdr-app/`; edit
the repo copy, commit, and relink a folder mod to reload it
(`rm ~/.config/herdr-app/mods/<name> && ~/projects/dotfiles/.config/install.sh`):

- `keys.json`, `layouts/main-folders.json` (the layout in use),
  `themes/vibe.json`, `themes/house.json`
- mods: `space-folders`, `github`, `github-button`, `two-pane-spaces`,
  `sessions`, `session-agents`, `session-picker`

Everything else (shipped layouts and mods, `settings.json`, state files) is
local to this machine. `bin/herdr-app-setup` in dotfiles checks the setup.

## Terminal labels we use

- `lifetime=long`: a bot that never ends. `session-agents` shows it with ∞
  and counts it apart from tasks. `hc label <t> lifetime=` clears it.
- `goal=<tag>`: the agent's current goal, written by Claude's
  `~/.claude/set-label.sh` and shown on `session-agents` rows when nobody
  named the tab.

## Agents

- Codex runs as `codex --no-daemon` (a shared daemon breaks hc identity).
- `claude` is a shell function (`.functions`) that adds Remote Control;
  the app's launcher runs shell functions, so menu-started agents get it.
- The old Herdr TUI (`herdr`) is retired; don't use it.
