#!/usr/bin/env bash

# Install curated Codex files without overwriting Codex runtime state.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$REPO_DIR/.." && pwd)"
CODEX_DIR="$HOME/.codex"
BACKUP_DIR="$CODEX_DIR/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"
# rules/safety.rules is generated together with Claude's permissions.deny from
# ../agent-common/safety.json (repo-kit scripts/agent-policy.mjs); Codex reads
# every ~/.codex/rules/*.rules.
ITEMS=(hooks.json rules/safety.rules)

# link_one <item> [source]: link ~/.codex/<item> to the same path in this dir,
# or to [source] when the real file lives elsewhere in the repo.
link_one() {
  local item="$1"
  local src="${2:-$REPO_DIR/$item}"
  local dst="$CODEX_DIR/$item"

  if [ ! -e "$src" ]; then
    echo "skip (missing in repo): ${src#$DOTFILES_DIR/}"
    return
  fi

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok    $item"
    return
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$item")"
    mv "$dst" "$BACKUP_DIR/$item"
    echo "backup $item"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "link   $item"
}

mkdir -p "$CODEX_DIR"
for item in "${ITEMS[@]}"; do
  link_one "$item"
done

# ~/.codex/AGENTS.md is the one global rules file, GLOBAL_AGENTS.md at the repo
# root; claude/install.sh links ~/.claude/CLAUDE.md to the same file.
# An empty rules file would silently drop every global rule, so it is not linked.
if [ -s "$DOTFILES_DIR/GLOBAL_AGENTS.md" ]; then
  link_one AGENTS.md "$DOTFILES_DIR/GLOBAL_AGENTS.md"
else
  echo "skip  AGENTS.md (GLOBAL_AGENTS.md is missing or empty)"
fi

node "$REPO_DIR/scripts/apply-managed-config.mjs" "$CODEX_DIR/config.toml"
node "$REPO_DIR/../agent-common/sync-agent-tooling.mjs" install
