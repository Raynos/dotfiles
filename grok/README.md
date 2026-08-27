# Grok tooling

Curated personal Grok CLI configuration, parallel to `../codex/`. Run
`./install.sh` to apply the managed config defaults.

## What is managed

- `config.managed.toml` — `[features] feedback = false`, which disables the
  `/feedback` command and its rating prompts. This mirrors
  `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1` in `../claude/settings.managed.json`.

## What remains native or runtime-owned

`~/.grok/config.toml` also holds `[cli]` installer state, `[marketplace]`
sources and purge flags, the `[privacy]` banner acknowledgement, and `[ui]`
toggles. `[ui]` is deliberately unmanaged: `compact_mode`, `permission_mode`,
and `yolo` are flipped from inside the TUI at runtime, so managing the table
wholesale would fight every toggle. The installer replaces only the declared
sections; it never rewrites the file.

Telemetry is a separate switch from feedback — `[features] telemetry`, or
`GROK_TELEMETRY_ENABLED` — and is intentionally left at Grok's default rather
than pinned here. Note that xAI's prebuilt binary can carry compile-time
telemetry defaults baked in via `GROK_TELEMETRY_BUILD_*`, so the documented
"unset by default" behavior of public source builds does not necessarily apply.

Auth (`auth.json`, `agent_id`), sessions, logs, worktrees, and marketplace
caches are never versioned.
