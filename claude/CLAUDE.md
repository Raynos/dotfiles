# Global guidance (applies to all my sessions)

## Keep the status-line session label current

The terminal status line renders `<model> — <this session's high-level goal>`.
You own that goal string. At the **start of a task**, and **whenever the goal
materially shifts**, set it by running:

```
~/.claude/set-label.sh "<=50 char goal, git-branch / PR-title style>" "<=12 char tag>"
```

**Both args are required** (the script errors otherwise). Arg 1 is the
status-line goal — **quote it**, it's a single argument. Arg 2 is a short tag
(≤12 chars) that mirrors into the **herdr agents panel** when running inside
herdr (a no-op otherwise) — keep it terse and legible, it's a chip, not a
sentence (e.g. `herdr-tag`, `andon-ui`, `t0-econ`).

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
