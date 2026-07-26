# Global guidance (applies to all my sessions)

## Keep the status-line session label current

The terminal status line renders `<model> — <this session's high-level goal>`.
You own that goal string. At the **start of a task**, and **whenever the goal
materially shifts**, set it by running:

```
~/.claude/set-label.sh "<=50 char goal, git-branch / PR-title style>" "<=24 char tag>"
```

**Both args are required** (the script errors otherwise). Arg 1 is the
status-line goal — **quote it**, it's a single argument. Arg 2 is a short tag
(≤24 chars) that mirrors into the **herdr agents panel** when running inside
herdr (a no-op otherwise) — it now owns a full sidebar row, so it can be a short
phrase rather than a chip, but it still truncates and never wraps
(e.g. `herdr sidebar layout`, `andon steel palette`, `flaky combat e2e`).

The herdr half is **two coupled pieces** — if the chip stops showing up, check
both: `set-label.sh` writes pane metadata token `goal`, and
`dotfiles/.config/herdr/config.toml` has the `[ui.sidebar.agents]` row that
renders `$goal`. A token with no matching row renders nothing, silently. (herdr
0.7.x replaced the old one-shot `--custom-status` flag with this token model.)

- Imperative and concrete, no trailing punctuation — e.g.
  `Migrate estate map to Andon Steel palette`, `Fix flaky combat e2e test`.
- It's a trivial local file write: no cost, no background process, no
  confirmation needed. Just do it inline as part of your work.
- It's the **headline, not a progress log** — don't rewrite it every small
  step; update it when *what you're fundamentally working on* changes.
- A manual `/rename` by the human always overrides it. If you never set it, the
  status line falls back automatically: your current in-progress **TODO**, else
  the latest typed **prompt**. So this is best-effort — keep it fresh, but it's
  not a gate.
- A `UserPromptSubmit` hook may inject a `[status-line reminder]` when the label
  is unset or stale (>20 min). Act on it if the goal is clear; ignore it if not.

## Claude Code sound hooks (Warcraft 3 voice chimes)

I have audio hooks that play Warcraft 3 unit voices when Claude Code needs me.
They live in `~/.claude/sounds/` (symlinked to `dotfiles/claude/sounds/`) and are
wired in `~/.claude/settings.json`. When touching them, know the layout:

- **`play.sh <complete|question|permission>`** — plays a *random* clip from
  `sounds/warcraft3-en/<cat>-*.wav`. Per-category default volume (`afplay -v`);
  override with `CC_SOUND_VOL`. **`question` is boosted to `3.0`** on purpose so
  decision prompts are impossible to miss; the others are `1.25`.
- **Wiring (in `~/.claude/settings.json`) — every "Claude needs me" event plays the
  multi-second `question` voice, no classification layer:**
  - **`PreToolUse` matcher `AskUserQuestion`** → `play.sh question`. This is the
    reliable one: it fires the instant the ask tool is called, **regardless of
    terminal focus**, so a question I ask is never silent.
  - **`Notification`** hook → `play.sh question` directly. (The old `notify.sh`
    classifier that split permission-vs-question is **retired** — it misrouted every
    ask-tool prompt into the sub-half-second permission blurbs, and the
    `Notification` event is focus/delay-gated so it can't be relied on alone.)
  - **`Stop`** hook → **`stop-if-idle.sh`** → plays **`complete`** only when the
    session is genuinely idle (no `background_tasks`/`session_crons` pending).
- **`audit.sh`** — shared logger + payload parser. **Every** play/suppress lands in
  **`~/.claude/sounds/play.log`** with session/cwd/category/reason/file/vol —
  `tail -f` it to see exactly what fired and why. `CC_SOUND_DEBUG=1` dumps raw
  payloads to `payload-debug.log`.

**Clip inventory** (`warcraft3-en/`) — **all VOICE now (English Peasant/Peon), no
music/SFX** (rebuilt 2026-07-07; the old stereo music tracks that had no voice are
parked in `warcraft3-en/_old-nonvoice-*/`): `complete-*` (job's-done acks —
"Job's done" / "Work complete" / "Ready to work"), `permission-*` (short 0.3–1.2s
blurbs — "Yes?" / "What is it?"), `question-*` (the **"annoyed / clicked-again"**
Peasant/Peon *Angry* lines, 0.4–3.4s — "I'm working, I'm working!" — the
attention-grabbers I actually want to hear). **Source:** the multi-second annoyed
`*Angry*` lines come from **`PeonPing/og-packs`** (`peasant/`,`peon/` = English) —
NOT warmwind, whose repo is only short unit-acks (`PeasantWhat`, `PeonYes`,
`jobs_done.mp3`) that seed `permission-*`/`complete-*`.

**Gotcha:** the `Notification` hook alone is focus/delay-gated (fires only when the
terminal is unfocused or a prompt sits unanswered a beat) — which is exactly why the
`PreToolUse` hook exists: it fires deterministically on tool-call, so ask prompts are
never silent. **`settings.json` hook edits only take full effect on a session
restart.** Check `play.log` before assuming the wiring is broken.
