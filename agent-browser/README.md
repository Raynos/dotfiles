# agent-browser

Official Vercel browser CLI plus its version-matched skill. Headless by default.

```sh
./agent-browser/install.sh
agent-browser skills get core
agent-browser --session my-task open https://example.com
agent-browser --session my-task snapshot -i
agent-browser --session my-task close
```

The installer uses the pin in `version` with `pnpm add -g`, so switching nvm
versions keeps the command available in pnpm's global bin (`~/Library/pnpm` on
macOS). It installs Chrome for Testing and links
the managed config to `~/.agent-browser/config.json`. The canonical skill in
`agents/skills/agent-browser` is linked into `~/.agents/skills` (including Codex)
and `~/.claude/skills`. Use a distinct named session for each task.

The skill was fetched from `vercel-labs/agent-browser`, tag `v0.37.1`, commit
`72007a6788d863611b23bed0b59d0d659c638d8e`, path `skills/agent-browser`, using
the Codex skill installer. Its discovery stub loads current instructions from
`agent-browser skills get core`. Upstream license: Apache-2.0 (see `LICENSE`).
Update the version pin, refresh the upstream skill if needed, and rerun the
installer. Never add browser profiles, auth state, sockets, caches or recordings
to dotfiles.

For a project-local discovery link, point `.agents/skills/agent-browser` and
`.claude/skills/agent-browser` at the canonical skill and exclude those personal
links in that checkout's `.git/info/exclude`. No game dependency is required.
