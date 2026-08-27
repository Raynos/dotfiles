# dcg (Destructive Command Guard)

Pinned install of [dcg](https://github.com/Dicklesworthstone/destructive_command_guard),
a Rust `PreToolUse` hook that blocks destructive shell commands before an agent
can run them. It reads the proposed command as JSON on stdin and returns a
verdict — it never executes anything itself.

Agents here run with `defaultMode: bypassPermissions`, so this is a real gate,
not a second opinion. The scope is deliberately narrow (see *What's NOT
tracked*): recursive `rm`, destructive git, and disk-destroying commands.

## Install

```
./install.sh
```

Fetches the pinned release artifact, verifies its SHA256 (mandatory) and
minisign signature (when `minisign` is installed), installs the binary to
`~/.local/bin/dcg`, and symlinks `config.toml` into `~/.config/dcg/`.
Idempotent — re-run any time. **To update:** bump `DCG_VERSION` in
`install.sh` and re-run.

Upstream ships a 149 KB `curl | bash` installer. This repo does not use it. It
self-updates, rewrites `~/.claude/settings.json` behind the managed-settings
merge, and appends a `jq`-on-every-shell-startup check to `.bashrc`/`.zshrc`
(which would undo the interactive-bash startup work in a82f359). Our installer
downloads one pinned artifact and executes none of their shell.

## What's tracked

| Item          | What it is |
|---------------|------------|
| `install.sh`  | Pinned fetch + SHA256/minisign verify + config symlink |
| `config.toml` | The managed `[general]` keys (rationale below) |

Hook wiring lives with each agent, so this repo stays the only writer:

| Agent  | Where |
|--------|-------|
| Claude | `../claude/settings.managed.json` — `PreToolUse` entry 1, matcher `Bash\|PowerShell`, ahead of `guard-rm.py` |
| Codex  | `../codex/hooks.json` — `PreToolUse`, matcher `Bash` |
| Grok   | `../grok/hooks/dcg.json` — symlinked to `~/.grok/hooks/`, auto-discovered |

Cursor is not wired here: `~/.cursor` hooks belong to the private
`Raynos/work-skills` repo.

Two quirks worth knowing before you edit the Claude entry:

- **It carries no `timeout` key on purpose.** `dcg doctor`'s hook-wiring check
  demands the hook object be *exactly* `{type, command}` — two keys, byte-equal
  to what dcg would write — so adding `"timeout": 5` turns doctor permanently
  red. (dcg contradicts itself here: its self-heal path explicitly tolerates an
  operator-set `timeout`, their #345. Doctor does not.) A red doctor trains you
  to ignore doctor, and this repo uses it as the drift signal, so the key is
  omitted. dcg self-bounds at a 1000 ms evaluation budget anyway.
- **`dcg doctor` always reports one issue: OpenCode NOT REGISTERED.** OpenCode
  isn't installed here. Expected — everything else should read OK.

## What's NOT tracked (deliberately)

- **The binary.** Reproducible from the pin in `install.sh`. dcg is MIT *plus
  an OpenAI/Anthropic rider*, so neither its source nor its binary is vendored
  into this public repo — we install it, we don't redistribute it.
- `~/.config/dcg/allowlist.toml` — written by `dcg allowlist add` and
  `dcg allow-once`; runtime-owned.
- dcg's history/stats database and pending-exception store — runtime state.
- Extra packs. The defaults (`core.filesystem`, `core.git`, `system.disk`) are
  the whole intended scope; `database.*`, `kubernetes.*`, `cloud.*` and the
  other ~99 packs stay off.

## Rationale for the managed keys

- **`self_heal_hook = false`** — dcg defaults to re-registering itself in
  `~/.claude/settings.json` on *every* hook invocation when it can't find its
  canonical entry. `apply-managed-settings.mjs` has to stay the single writer
  of the managed subset, so self-heal is off and the managed entry is written
  in dcg's canonical shape instead (absolute path, `Bash|PowerShell` matcher).
  If `~/.config/dcg/config.toml` ever dangles, dcg reverts to defaults and
  starts rewriting settings.json — the managed-settings `--check` drift
  failure is the signal.
- **`unverified_decision = "deny"`** — dcg defaults to `ask` when it can't
  verify a command (evaluation deadline, oversized input). This repo never
  asks: an ask once left an unattended agent blocked for 23h (2026-07-31), the
  incident that produced `guard-rm.py`'s allow-or-block-only contract.
- **`check_updates = false`** — updates come from bumping the pin.
- **`guard-rm.py` stays chained second** behind dcg for now. Its narrower rules
  can only add blocks, never lift dcg's, but it is the known-good backstop
  while dcg is on trial.

## Known policy difference from guard-rm.py

dcg is **stricter**. It denies variable-rooted and relative recursive deletes
that `guard-rm.py` deliberately allowed:

| Command | guard-rm.py | dcg |
|---------|-------------|-----|
| `rm -rf "$SOME/$VAR"` | allow (unresolvable without a shell) | **deny** (`core.filesystem:rm-rf-general`) |
| `rm -rf node_modules` | allow | **deny** |
| `rm -rf /tmp/…`, `/private/tmp/…` | allow | allow (literal temp paths are safe-listed) |
| `rm -rf /`, `~`, `/*` | deny | deny |

This is a deny, never an ask, so it cannot stall an unattended run — the agent
gets an immediate structured denial. Escape hatches, cheapest first:

- `dcg allow-once <code>` using the short code printed in the denial panel
- `DCG_BYPASS=1 <command>` for a single invocation
- `dcg allowlist add <rule-id> -r "reason"` for a recurring need
- If trial friction is bad, downgrade the five general rm rules to warn (allow
  + stderr warning) in `config.toml`, keeping root/home/glob rules at deny:

  ```toml
  [policy.rules]
  "core.filesystem:rm-rf-general" = "warn"
  "core.filesystem:rm-r-f-separate" = "warn"
  "core.filesystem:rm-recursive-force" = "warn"
  "core.filesystem:rm-recursive-force-long" = "warn"
  "core.filesystem:rm-recursive-general" = "warn"
  ```
