# Cursor config

Curated Cursor user config, symlink-managed by `./install.sh` (run
automatically from `bootstrap.sh`, or run it directly). The repo holds the
real files; `~/Library/Application Support/Cursor/User/` gets symlinks back
here, so edits made in Cursor's settings UI flow straight into git.

## What's tracked

- `settings.json` — editor/TS/git preferences, plus the big
  "silence every accessibility signal" block.
- `keybindings.json` — custom keybindings.
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
