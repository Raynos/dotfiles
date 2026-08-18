#!/usr/bin/env bash
#
# Declarative Claude Code plugin sync — the VS Code `code --list-extensions` /
# `code --install-extension` model, applied to `claude plugin`.
#
#   ./sync-plugins.sh export    # snapshot installed plugins -> plugins.json (commit it)
#   ./sync-plugins.sh install   # install everything in plugins.json (default)
#   ./sync-plugins.sh diff      # show what install would add, without doing it
#
# We version plugins.json (a clean id + scope list derived from the CLI), NOT
# ~/.claude/plugins/ — that dir is fetched plugin CODE plus a churn-y state file
# full of absolute paths, timestamps, and git SHAs. Same split as VS Code: you
# commit the extensions list, never the extensions install dir.
#
# `enabled` is intentionally not tracked: the CLI reports it session-dependently
# (false when run headless), and a freshly installed plugin is enabled anyway.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$REPO_DIR/plugins.json"

command -v claude >/dev/null || { echo "error: 'claude' CLI not found" >&2; exit 1; }
command -v jq >/dev/null     || { echo "error: 'jq' not found" >&2; exit 1; }

# Our gitconfig sets submodule.recurse=true, which breaks `claude plugin
# install`'s internal `git checkout <pinned sha>` on repos with uninitialized
# submodules (e.g. chrome-devtools-mcp's devtools-frontend). Override for
# every git the CLI spawns from here.
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=submodule.recurse GIT_CONFIG_VALUE_0=false

cmd="${1:-install}"

case "$cmd" in
  export)
    mk="$(claude plugin marketplace list --json)"
    pl="$(claude plugin list --json)"
    jq -n --argjson m "$mk" --argjson p "$pl" '
      {
        marketplaces: ($m | map({name, source, repo}) | sort_by(.name)),
        plugins:      ($p | map({id, scope})          | sort_by(.id))
      }' > "$FILE"
    echo "wrote $(jq '.marketplaces|length' "$FILE") marketplaces, \
$(jq '.plugins|length' "$FILE") plugins -> ${FILE#$HOME/}"
    ;;

  install|diff)
    [ -f "$FILE" ] || { echo "error: $FILE not found (run 'export' first)" >&2; exit 1; }
    dry=""; [ "$cmd" = diff ] && dry="1"

    # Marketplaces first (a plugin install needs its marketplace present).
    have_mk="$(claude plugin marketplace list --json | jq -r '.[].name')"
    while IFS=$'\t' read -r name repo; do
      if grep -qxF "$name" <<<"$have_mk"; then
        echo "marketplace ok   $name"
      elif [ -n "$dry" ]; then
        echo "marketplace ADD  $name ($repo)"
      else
        echo "marketplace add  $name ($repo)"
        claude plugin marketplace add "$repo"
      fi
    done < <(jq -r '.marketplaces[] | [.name, .repo] | @tsv' "$FILE")

    # Then plugins. Project-scoped installs are tied to a specific project dir,
    # so they aren't portable to a fresh machine — list them, don't install.
    have_pl="$(claude plugin list --json | jq -r '.[].id')"
    while IFS=$'\t' read -r id scope; do
      if grep -qxF "$id" <<<"$have_pl"; then
        echo "plugin ok        $id"
      elif [ "$scope" = project ]; then
        echo "plugin SKIP      $id (project-scoped — install from inside its project)"
      elif [ -n "$dry" ]; then
        echo "plugin INSTALL   $id"
      else
        echo "plugin install   $id"
        claude plugin install "$id" --scope "$scope"
      fi
    done < <(jq -r '.plugins[] | [.id, .scope] | @tsv' "$FILE")

    if [ -n "$dry" ]; then echo "(diff only — nothing changed)"; fi
    ;;

  *)
    echo "usage: $0 {export|install|diff}" >&2; exit 2
    ;;
esac
