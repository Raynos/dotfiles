# Suggested human-only edits

## README.md:3 — the Herdr TUI is gone

The per-tool list says "herdr"; the TUI config (`.config/herdr/`) was removed
and only the Herdr app (`.config/herdr-app/`, `herdr-gitview/`) remains.
Suggested wording:

    Shell dotfiles plus per-tool installers (Claude Code, Codex, Cursor, the
    Herdr app, pnpm, ...

## AGENTS.md — Herdr

Optional: under "What this repo is", note that Herdr means the app
(`herdr-app`) plus herdr-core (`hc`); the old `herdr` TUI is retired, and
`~/.config/herdr-app/AGENTS.local.md` (linked from this repo) holds the
setup notes agents should read.
