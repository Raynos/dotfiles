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
  experimental structured `request_user_input` tool and passes the launching
  process's exported environment to commands through
  `shell_environment_policy.inherit = "all"` and
  `ignore_default_excludes = true`.
- `../agent-common/tooling.json` — Context7, Playwright, Chrome DevTools, and
  Browser Use capability intent.

## What remains native or runtime-owned

`~/.codex/config.toml` also contains project trust, marketplace locations,
plugin state, and OAuth-related data. The installer updates only the declared
top-level scalar settings and declared table sections; it never replaces the
file. App-owned subtables, including `shell_environment_policy.set`, remain
intact. OAuth, session data, plugin caches, and project trust records are never
versioned.

Export variables before starting a new CLI session, for example run
`export MY_FLAG=1` and then `codex`. Herdr-provided variables such as `HERDR_ENV` are
inherited when Codex is launched from that pane. The policy cannot recover
variables absent from the Codex process's environment; an already-running
app-server daemon must receive them at startup or through its client.

Codex has no documented equivalent of Claude Code's terminal status line or
`Notification` lifecycle hook. The existing Herdr `SessionStart` integration
is shared; notification sounds and status labels remain Claude-specific.

Run `node ../agent-common/sync-agent-tooling.mjs check` to detect a missing
capability. `export` refreshes the credential-free Codex MCP commands in the
manifest, while preserving its capability descriptions and Claude adapters.
`install` adds missing declared Codex MCP servers and plugins, but never
removes configuration or copies private plugin or authentication state. The
check treats the declared Claude plugins and Codex MCP/plugin adapters as
equivalent capabilities.
