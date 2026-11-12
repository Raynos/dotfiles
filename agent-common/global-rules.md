# Global guidance for every agent (Claude Code and Codex)

One file, read by both tools: `~/.codex/AGENTS.md` links here and
`~/.claude/CLAUDE.md` imports it. Claude-only parts (status line, sound
hooks) stay in `claude/CLAUDE.md`.

## Repository policy and personal config

Use the repository's `AGENTS.md` as the source of truth for project-specific
policy. Keep personal settings, tools, and hooks in this dotfiles repository;
never copy credentials, OAuth grants, session data, caches, or project trust
records into version control.

Use the shared tool inventory at
`~/projects/dotfiles/agent-common/tooling.json` to check the personal Claude
Code and Codex capability sets.

## Times are in Cancún

Jake (2026-11-10): "don't ever say UTC, it's cancun, say it in my mexico east
coast timezone." Jake lives in Cancún (America/Cancun, UTC−5 all year, no
DST). Give every time Jake reads in Cancún time (UTC minus 5 h) and don't
write "UTC"; logs and receipts can stay in UTC. Read the clock with
`date +%H:%M` (the Mac is on Cancún time), never estimate it.

## Licences: North and South America only

Everything made on this machine ships in North and South America only, so a licence's territory clause (Hunyuan3D's
EU / UK / South Korea exclusion, or any region limit) never applies. Never raise a territory caveat. Hunyuan3D is as
allowed as TRELLIS.2: use whichever looks better. Only non-commercial / research-only terms still matter for shipped
assets.

## `command not found` for a global CLI is almost never $PATH

If `vercel`, `socket`, `cdktf` or any other `npm i -g` CLI is suddenly not
found, **do not reinstall it and do not start editing $PATH.** The cause is
nvm, every time:

`npm i -g` under nvm installs into
`~/.nvm/versions/node/<version>/lib/node_modules` — **per node version**. The
next `nvm install` gives you a fresh version with an empty global prefix and
every one of those CLIs vanishes from `$PATH` at once. `$PATH` is correct; it
points at the current node's bin, which really does not have the tool. The old
copy is still on disk one directory over.

**Diagnose:** `node-global-doctor` (in `dotfiles/bin`, on `$PATH`) lists every
global stranded under a non-current node version. `--fix` re-installs them with
pnpm.

**Fix, and the rule going forward:** install user-level CLIs with
**`pnpm add -g <name>`**, not npm. pnpm's global bin is `~/Library/pnpm` on
macOS — one directory, already on `$PATH`, independent of which node nvm has
active. Install once, survives every node upgrade. Reserve `npm i -g` for the
rare tool that genuinely must match a node version.

## Vercel

For the REST API (`https://api.vercel.com`), when something is not exposed as a
CLI flag (project rename and deployment protection both are not), use the
**long-lived token in `~/.config/vercel/api-token`** (mode 600, created
2026-11-10, no expiry). Read it from the file; never print it. Scope is
`raynos-projects`.

Don't use the CLI's own token in
`~/Library/Application Support/com.vercel.cli/auth.json` for REST calls: since
CLI 59.x it expires after 8 hours, and only the CLI renews it on its next
command. The CLI itself stays logged in that way; if it says the login expired,
run `vercel whoami` before asking Jake to `vercel login`.

**Name the project before the first deploy.** `vercel deploy --prod --yes` run
from a build-output directory names the Vercel project after *that directory*,
which is how one game shipped on `dist-three-rho-86.vercel.app` — the project
was literally called `dist`. Deploy from the repo root, or pass an explicit
name. Renaming afterwards works but does not move the domain: rename with
`PATCH /v9/projects/<id>`, then `POST /v10/projects/<name>/domains` to attach
`<name>.vercel.app`, or the new URL 404s while the old one keeps serving.
