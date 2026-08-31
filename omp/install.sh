#!/usr/bin/env bash

# Apply curated Oh My Pi (omp) config without overwriting omp runtime state.
#
# The repo owns two things here: `agent/models.yml` (the custom local-model
# providers) and `agent/extensions/` (personal slash commands). Everything else
# in ~/.omp/agent is runtime-owned — config.yml is rewritten by omp itself
# (setupVersion, modelRoles, every `omp config set`), and the *.db files,
# sessions/ and cache/ are session state. Linking any of those would either
# lose writes or version a moving target.
#
# Only the DEFAULT profile is managed. `omp --profile <name>` reads
# ~/.omp/profiles/<name>/agent instead, which is deliberately left alone.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMP_DIR="${OMP_HOME:-$HOME/.omp}"
BACKUP_DIR="$OMP_DIR/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

# Curated items, path-relative to BOTH the repo dir and ~/.omp.
ITEMS=(
  agent/models.yml
  agent/extensions/effort-command.ts
)

link_one() {
  local item="$1"
  local src="$REPO_DIR/$item"
  local dst="$OMP_DIR/$item"

  # Already the correct symlink? Nothing to do.
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok    $item"
    return
  fi

  # Back up whatever is currently there (real file or stale symlink).
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$item")"
    mv "$dst" "$BACKUP_DIR/$item"
    echo "backup $item -> ${BACKUP_DIR#"$HOME"/}/$item"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "link   $item -> ${src#"$HOME"/}"
}

mkdir -p "$OMP_DIR/agent"
for item in "${ITEMS[@]}"; do
  link_one "$item"
done
