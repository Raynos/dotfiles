# Codex tooling

Curated personal Codex configuration, parallel to `../claude/`. Run
`./install.sh` to link global guidance and hooks, apply the managed scalar
defaults, and install/check the shared tool capability inventory.

## What is managed

- `AGENTS.md` — global, personal working agreements.
- `hooks.json` — the Codex Herdr `SessionStart` adapter.
- `config.managed.toml` — model and permission defaults. `approval_policy =
  "never"` plus `sandbox_mode = "danger-full-access"` intentionally mirrors
  the approved Claude Code bypass-permissions behavior. It also enables the
  experimental structured `request_user_input` tool.
- `../agent-common/tooling.json` — Context7, Playwright, Chrome DevTools, and
  Browser Use capability intent.

## What remains native or runtime-owned

`~/.codex/config.toml` also contains project trust, marketplace locations,
plugin state, and OAuth-related data. The installer updates only the declared
top-level scalar settings; it never replaces the file. OAuth, session data,
plugin caches, and project trust records are never versioned.

Codex has no documented equivalent of Claude Code's terminal status line or
`Notification` lifecycle hook. The existing Herdr `SessionStart` integration
is shared; notification sounds and status labels remain Claude-specific.

Run `node ../agent-common/sync-agent-tooling.mjs check` to detect a missing
capability. The check treats the declared Claude plugins and Codex MCP/plugin
adapters as equivalent capabilities; it does not copy one product's private
plugin or authentication state into the other.
