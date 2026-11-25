---
name: herdr
description: "Drive Herdr: herdr-core (`hc`), which runs every terminal and agent, and the Herdr app (`herdr-app`), the desktop window with spaces, tabs, layouts, keys and mods. Use only when the user explicitly mentions Herdr or hc, or asks to inspect or control terminals, agents, spaces, tabs or the Herdr window. Do not use merely because a task could benefit from a background terminal, delegation, or parallel work."
---

# Herdr (herdr-core + the Herdr app)

Two programs. Both print their own current manual, so this skill only points
at them and never goes stale:

- **`hc` (herdr-core)** runs every terminal and agent: start, read, send,
  wait, label, other machines. Run `hc --skill` and follow it.
  Inside an hc terminal, `$HC_TERMINAL_ID` is your address.
- **`herdr-app`** is the window: spaces, tabs, layouts, keys, mods.
  Run `herdr-app --skill`, then read `~/.config/herdr-app/AGENTS.md` and
  `~/.config/herdr-app/AGENTS.local.md` (this setup's notes).

The old Herdr TUI (`herdr`, `HERDR_ENV`, `HERDR_PANE_ID`) is gone. Never use
the `herdr` CLI.

## This setup

- The window runs on the MacBook. The Mac mini (`mini`) only runs herdr-core,
  reached by the MacBook's window over SSH, so `herdr-app` commands fail on
  the mini. Drive it with `hc` there, or `hc --on mini ...` from the MacBook.
- Codex always runs as `codex --no-daemon` under hc.
- Our layouts, mods, themes and `keys.json` are symlinks into
  `~/projects/dotfiles/.config/herdr-app/`: edit them there and commit.
  A folder mod reloads only when relinked:
  `rm ~/.config/herdr-app/mods/<name> && ~/projects/dotfiles/.config/install.sh`.
- Shipped layouts and mods are the app's: clone before changing structure.
  Never edit the app's `AGENTS.md` or `*.d.ts`; it rewrites them on start.
