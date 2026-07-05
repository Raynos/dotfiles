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

## Plugins — declarative sync (the VS Code model)

Claude Code has a headless plugin CLI (`claude plugin list/install`,
`claude plugin marketplace add`) — the exact analog of VS Code's
`code --list-extensions` / `code --install-extension`. So plugins sync the same
way VS Code extensions do in a dotfiles repo: **version the derived list, not the
install dir.**

- **`plugins.json`** — the committed list (marketplace `name`+`repo`, plugin
  `id`+`scope`), derived from the CLI. This is the source of truth.
- **`sync-plugins.sh`** — the two-way tool:

  ```bash
  ./sync-plugins.sh export     # snapshot installed plugins -> plugins.json (commit it)
  ./sync-plugins.sh diff       # preview what a fresh install would add
  ./sync-plugins.sh install    # add marketplaces + install every plugin in the list
  ```

`install.sh` runs `sync-plugins.sh install` automatically, so a fresh machine
gets the plugins after the symlinks. **After you add/remove a plugin, run
`./sync-plugins.sh export` and commit `plugins.json`** — that keeps the list
current (same discipline as re-exporting VS Code extensions).

What is *not* versioned: `~/.claude/plugins/` — the fetched plugin code plus a
churn-y `installed_plugins.json` state file (absolute paths, timestamps, git
SHAs). Reproduced from `plugins.json`, never committed. Project-scoped installs
(e.g. `frontend-design`) are tied to a project dir, so `install` lists but skips
them — install those from inside their project.
