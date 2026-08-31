# Oh My Pi (omp) tooling

Curated personal omp configuration, parallel to `../codex/` and `../grok/`.
Run `./install.sh` to symlink the managed files into `~/.omp/agent`.

## What is managed

- `agent/models.yml` — the custom local-model providers. Currently one:
  `mtplx-local`, MTPLX serving Qwen3.8-27B on `127.0.0.1:18091` with a 262,144
  native context. A malformed entry here disables **all** custom providers, not
  just the bad one, so validate the file before trusting a session.
- `agent/extensions/effort-command.ts` — adds `/effort`, a slash command that
  sets the session thinking level (`off · minimal · low · medium · high ·
  xhigh · max`) with argument completion. omp ships only the keyboard route —
  `shift+tab` cycles (`app.thinking.cycle`) and `ctrl+t` toggles
  (`app.thinking.toggle`) — and this exists because those chords are
  unmemorable. It calls the extension API's `setThinkingLevel`, the same seam
  the keybindings drive, so the status line follows.

`~/.omp/agent/extensions/*.ts` is auto-discovered; no settings entry is needed
to load an extension from there.

## What remains native or runtime-owned

`~/.omp/agent/config.yml` is written by omp itself — `setupVersion`,
`modelRoles`, and every `omp config set` land there — so it is merged by hand,
never linked. Same for `keybindings.yml`, which omp rewrites on load when it
migrates a legacy `keybindings.json`. `agent.db`, `models.db`, `history.db`,
`sessions/` and `cache/` are session state and are never versioned.

Only the default profile is managed. `omp --profile <name>` reads
`~/.omp/profiles/<name>/agent`, which this installer does not touch.

## Notes

- **No secrets here.** `models.yml` may name an env var in `apiKey`, never a
  key value. A local engine that needs no auth uses `auth: none` instead —
  omp rejects the whole file if a custom provider has neither.
- Local Studio's controller route (`127.0.0.1:18088`) used to be a second
  provider in `models.yml`. It was removed on 2026-08-31; MTPLX direct is both
  faster and 4x deeper in context.
