# herdr skill (auto-installed)

`SKILL.md` here is the **canonical upstream herdr agent guide**, installed
verbatim so Claude Code sessions know how to drive herdr from inside a pane.

- **Source:** https://raw.githubusercontent.com/ogulcancelik/herdr/master/SKILL.md
- **Do not hand-edit `SKILL.md`** — it is replaced wholesale on refresh.
- **Refresh it (keeps it from going stale):**

  ```sh
  ~/.claude/skills/herdr/update.sh
  ```

herdr ships no official skill-install command (re-verified 2026-07-26 against
herdr 0.7.5 — `herdr integration install <agent>` only installs the lifecycle
hook, not the skill), so `update.sh` is the recommended way: it fetches upstream,
sanity-checks that it still starts with valid frontmatter, and swaps it in
atomically (leaving the old copy untouched on any failure).

**Re-run `update.sh` after every `herdr update`.** The skill goes stale fast and
silently. Between 0.6.x and 0.7.5 the guide was rewritten (300 → 195 lines) and
the public ID format changed — panes went from `1-2` to `w2:p1`, tabs from `1:2`
to `w2:t1` — so a stale copy hands out IDs the CLI rejects. 0.7.5 also replaced
the top-level `wait` commands with `agent wait` / `pane wait-output`, and
`agent send` with `agent send-keys`.

Live truth always beats the doc: `herdr <cmd> --help` reflects the actual
installed CLI, and `herdr api schema --json` is the authoritative field list.
(`herdr agent explain <target>` explains one agent target, not the CLI surface.)
