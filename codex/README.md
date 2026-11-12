# Codex tooling

Curated personal Codex configuration, parallel to `../claude/`. Run
`./install.sh` to link global guidance and hooks, apply the managed scalar
defaults, and install/check the shared tool capability inventory.

## What is managed

- `AGENTS.md` — a link to `../agent-common/global-rules.md`, the global rules
  both tools read; `~/.claude/CLAUDE.md` imports the same file and keeps only
  the Claude-only parts (status line, sounds).
- `hooks.json` — the Codex Herdr `SessionStart` adapter, plus the PreToolUse
  guards shared with Claude Code: `dcg`, `guard-chrome-keychain.py` and
  `guard-rm.py` (the scripts live in `../claude/hooks/`). Sounds, the session
  label reminder, `clear-herdr-tag.sh` and `auto-deny.sh` stay Claude-only;
  the reasons are in `../agents/parity.json`.
- `rules/safety.rules` — Codex execpolicy refusals, generated with Claude's
  `permissions.deny` from `../agent-common/safety.json` by repo-kit's
  `scripts/agent-policy.mjs`. Edit the spec, not either output.

`node <repo-kit>/scripts/agent-parity.mjs --global --strict` checks
`~/.claude` against `~/.codex` and `~/.agents`; one-sided items are accepted
in `../agents/parity.json`. Changing a hook's text changes Codex's trust hash:
open `codex` once and choose "Trust all and continue".
- `config.managed.toml` — model and permission defaults. `approval_policy =
  "never"` plus `sandbox_mode = "danger-full-access"` intentionally mirrors
  the approved Claude Code bypass-permissions behavior. It also enables the
  experimental structured `request_user_input` tool and passes the launching
  process's exported environment to commands through
  `shell_environment_policy.inherit = "all"` and
  `ignore_default_excludes = true`. `features.daemon_auto_start = false`
  disables automatic startup of the shared app-server daemon.
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
`export MY_FLAG=1` and then `codex`. With no shared daemon running, CLI
sessions execute locally and inherit Herdr-provided variables such as
`HERDR_ENV` from the launching pane. No shell alias or command wrapper is
installed.

Disabling automatic startup does not bypass a daemon that is already running.
Use `codex --no-daemon` or `codex --no-daemon resume <session-id>` to bypass
one. To restore the plain `codex` behavior, inspect its sessions with
`codex agents`, then stop it with `codex app-server daemon stop` when it is
safe to interrupt them. The shared-daemon environment issue and workaround
are tracked in [Codex #24638](https://github.com/openai/codex/issues/24638)
and [Herdr #4649](https://github.com/herdrdev/herdr/issues/4649).

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
