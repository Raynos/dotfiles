# Claude Code sound hooks

Warcraft 3 Peasant and Peon voice lines that play when a Claude Code session
needs Jake.

 - `claude/install.sh` links this directory to `~/.claude/sounds/`.
 - The hooks are wired in `claude/settings.managed.json`, which the installer
   merges into `~/.claude/settings.json`. A session reads its hooks at start, so
   a wiring change needs a session restart.

## What plays when

| Hook event     | Script            | Sound |
| -------------- | ----------------- | ----- |
| `Notification` | `notify.sh`       | `permission` when the payload mentions "permission", otherwise `question` |
| `Stop`         | `stop-if-idle.sh` | `complete`, only when the session has no background tasks or crons pending |

There is no hook on the `AskUserQuestion` tool. Notes that used to live in the
global CLAUDE.md described one (`PreToolUse` → `play.sh question`) and called
`notify.sh` retired. Neither is in `settings.managed.json` or its git history
(checked 2026-11-22). So a question makes a sound only when Claude Code fires
`Notification`. Those notes said that event waits until the terminal is
unfocused or the prompt has sat unanswered for a moment; nothing in this repo
confirms that.

## Scripts

 - `play.sh <complete|question|permission>`: plays a random
   `warcraft3-en/<category>-*.wav` with `afplay`. Volume is 3.0 for `question`
   and 1.25 for the others; `CC_SOUND_VOL` overrides it. Exits quietly when the
   category has no clips.
 - `notify.sh`: the `Notification` hook. Picks the category, then calls
   `play.sh`.
 - `stop-if-idle.sh`: the `Stop` hook. Stop fires at every turn end, so it stays
   silent while the payload lists `background_tasks` or `session_crons`. Without
   `jq` it cannot tell, and plays.
 - `audit.sh`: sourced by the others. Writes the log and parses the hook
   payload.

## Debugging

 - Every play and every suppressed play is one line in
   `~/.claude/sounds/play.log`: event, decision, category, reason, session,
   file, volume, cwd. Watch it with `tail -f`, and check it before deciding the
   wiring is broken.
 - `CC_SOUND_DEBUG=1` also writes each raw hook payload to `payload-debug.log`.
 - Both logs are git-ignored.

## Clips

All in `warcraft3-en/`, all English voice lines, no music or effects.

| Category     | Clips | Length    | Lines, as the old notes list them |
| ------------ | ----- | --------- | --------------------------------- |
| `complete`   | 6     | 1.0–2.1 s | "Job's done", "Work complete", "Ready to work" |
| `permission` | 16    | 0.3–1.2 s | "Yes?", "What is it?" |
| `question`   | 9     | 0.4–3.4 s | the annoyed lines, such as "I'm working, I'm working!" |

 - `_old-nonvoice-20260707-111515/` holds the music tracks the voice clips
   replaced on 2026-07-07.
 - Sources, as the old notes record them: the long annoyed lines come from
   `PeonPing/og-packs` (`peasant/` and `peon/` are the English packs). The
   warmwind repo only has short acknowledgements, which seeded `permission` and
   `complete`.
