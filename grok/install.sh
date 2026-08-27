#!/usr/bin/env bash

# Apply curated Grok config without overwriting Grok runtime state.
#
# Unlike claude/ and codex/, there is nothing to symlink here: Grok keeps no
# user-authored guidance or hook files in ~/.grok (README.md, docs/, and
# bundled/ are all vendor-shipped and replaced on update). The only thing this
# repo owns is the managed subset of config.toml.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROK_DIR="${GROK_HOME:-$HOME/.grok}"

mkdir -p "$GROK_DIR"
node "$REPO_DIR/scripts/apply-managed-config.mjs" "$GROK_DIR/config.toml"
