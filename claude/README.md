# Claude Code tooling

Curated, hand-authored Claude Code config that lives in `~/.claude`. The repo
holds the real files; `install.sh` symlinks them into `~/.claude` so live edits
flow straight back into git — nothing drifts or gets lost.

## Install (on any machine)

```bash
./install.sh          # symlinks the curated files into ~/.claude
```

Idempotent and safe: an existing real file at a target path is moved into a
timestamped `~/.claude/.dotfiles-backup-*` dir before the symlink is made.
Runtime state in `~/.claude` is never touched.

## What's tracked

| Item                       | What it is                                              |
| -------------------------- | ------------------------------------------------------- |
| `CLAUDE.md`                | Global instructions for all sessions                    |
| `settings.json`            | Permissions, hooks, statusline, model, theme            |
| `set-label.sh`             | Sets the status-line goal label (+ herdr tag)           |
| `session-label-remind.sh`  | `UserPromptSubmit` hook: nudge to refresh a stale label |
| `statusline.sh`            | Renders the terminal status line                        |
| `hooks/`                   | `herdr-agent-state.sh`, `clear-herdr-tag.sh`            |
| `skills/herdr/`            | The custom `herdr` skill                                |
| `sounds/`                  | Notification-sound scripts + `warcraft3-en/` wav assets |

## What's NOT tracked (deliberately)

Everything else in `~/.claude` is machine-local runtime state, not tooling, and
must never enter git: `.claude.json` (session/project state, auth), `history.jsonl`,
`projects/`, `sessions/`, `session-env/`, `shell-snapshots/`, `todos/`, `tasks/`,
`jobs/`, `backups/`, `cache/`, `daemon*`, `debug/`, `file-history/`, `paste-cache/`,
`stats-cache.json`, and installed plugin CODE under `plugins/cache|marketplaces|data`.

`settings.local.json` is a tiny per-machine permission allowlist that Claude
rewrites automatically — left machine-local on purpose.

## Plugins — reinstall list (declarative, not the live state file)

The live `plugins/installed_plugins.json` is a churn-y state file full of
machine-specific absolute paths, timestamps, and git SHAs that Claude rewrites on
every update — versioning it would just be noise. What's actually portable is the
*list* of what to install. On a fresh machine, add the marketplaces and plugins:

```
# Marketplaces
/plugin marketplace add anthropics/claude-plugins-official
/plugin marketplace add ChromeDevTools/chrome-devtools-mcp

# Plugins (all from claude-plugins-official)
/plugin install chrome-devtools-mcp@claude-plugins-official
/plugin install playwright@claude-plugins-official
/plugin install context7@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin install hookify@claude-plugins-official
/plugin install claude-md-management@claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
/plugin install frontend-design@claude-plugins-official   # installed per-project
```

Keep this list in sync when you add/remove a plugin (`/plugin` to see the
current set).
