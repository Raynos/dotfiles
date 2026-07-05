# herdr skill (auto-installed)

`SKILL.md` here is the **canonical upstream herdr agent guide**, installed
verbatim so Claude Code sessions know how to drive herdr from inside a pane.

- **Source:** https://raw.githubusercontent.com/ogulcancelik/herdr/master/SKILL.md
- **Do not hand-edit `SKILL.md`** — it is replaced wholesale on refresh.
- **Refresh it (keeps it from going stale):**

  ```sh
  ~/.claude/skills/herdr/update.sh
  ```

herdr ships no official skill-install command (verified 2026-07-04), so
`update.sh` is the recommended way: it fetches upstream, sanity-checks that it
still starts with valid frontmatter, and swaps it in atomically (leaving the old
copy untouched on any failure).

Live truth always beats the doc: `herdr <cmd> --help` and `herdr agent explain`
reflect the actual installed CLI.
