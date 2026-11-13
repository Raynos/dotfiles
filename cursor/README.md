# Cursor config

Curated Cursor user config, symlink-managed by `./install.sh` (run
automatically from `bootstrap.sh`, or run it directly). The repo holds the
real files; `~/Library/Application Support/Cursor/User/` gets symlinks back
here, so edits made in Cursor's settings UI flow straight into git.

## What's tracked

- `settings.json` — editor/TS/git preferences, plus the big
  "silence every accessibility signal" block.
- `keybindings.json` — custom keybindings.
- `tsc-lsp-proxy/` — a launcher and proxy the TypeScript 7 extension runs in
  place of its own server (`typescript.native-preview.tsdk` in
  `settings.json`). It caps the server at 4 cores and 4 GiB and ignores files
  outside the window's workspace folders, so files agents open from other
  worktrees stop loading a whole extra copy of a monorepo each. `install.sh`
  links it at `~/.local/share/tsc-lsp-proxy`. The memory limit follows
  `js/ts.server.goMemLimit` in `settings.json`; the core cap is the constant at
  the top of `proxy.js`. Extra directories to treat as inside the workspace go
  one per line in `~/.config/tsc-lsp-proxy/extra-roots`. To turn it off, delete the `tsdk` line and restart the TS
  server.
- `extensions.txt` — declarative extension list, one id per line
  (`cursor --list-extensions` format). `install.sh` installs anything missing;
  it never uninstalls extras.

## What's NOT tracked (deliberately)

- `~/.cursor/mcp.json` — carries per-server auth headers.
- `~/.cursor/hooks/`, `~/.cursor/rules/`, `~/.cursor/skills/` — partly
  symlinked from a private work repo.
- Cursor runtime state: `globalStorage/`, `workspaceStorage/`, `History/`,
  caches, login/session data.
- Machine-specific settings — e.g. `typescript.tsserver.nodePath` (hardcodes
  an nvm path); set it locally through the UI if a project needs it.
