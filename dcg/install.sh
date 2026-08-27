#!/usr/bin/env bash
#
# Install dcg (Destructive Command Guard) and link its managed config.
#
# Deliberately NOT upstream's curl|bash installer (149 KB, self-updating,
# rewrites agent settings files, appends a jq check to .bashrc/.zshrc). This
# fetches ONE pinned release artifact, verifies it (sha256 mandatory, minisign
# when available), and drops the binary into ~/.local/bin (already on PATH via
# .path). Hook wiring lives in ../claude/settings.managed.json,
# ../codex/hooks.json and ../grok/hooks/dcg.json; dcg never edits agent
# configs itself here (config.toml pins self_heal_hook = false).
#
# Update procedure: bump DCG_VERSION, re-run ./install.sh.
#
# Idempotent: the config symlink is checked every run; the download is skipped
# when the installed binary already reports the pinned version.
#
# Usage: ./install.sh
set -euo pipefail

DCG_VERSION="v0.13.5"
MINISIGN_PUBKEY="RWSoYi6NXJWzaRs1mJmOwwXrZfPWcq6MXnQlNMLBYKzlIQTLwuVQG6uO"
BASE_URL="https://github.com/Dicklesworthstone/destructive_command_guard/releases/download/${DCG_VERSION}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/dcg"
BACKUP_DIR="$CONFIG_DIR/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

# --- managed config: backup-then-link (same pattern as claude/install.sh) ---
link_config() {
  local src="$REPO_DIR/config.toml"
  local dst="$CONFIG_DIR/config.toml"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok    config.toml"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dst" "$BACKUP_DIR/config.toml"
    echo "backup config.toml -> ${BACKUP_DIR#"$HOME"/}/config.toml"
  fi
  mkdir -p "$CONFIG_DIR"
  ln -s "$src" "$dst"
  echo "link   config.toml -> ${src#"$HOME"/}"
}

# Linked before the version gate below, so a missing or stale symlink is
# repaired even when the pinned binary is already installed. That symlink is
# what keeps self_heal_hook off; if it dangles, dcg silently reverts to
# defaults and starts rewriting ~/.claude/settings.json.
link_config

# --- binary: skip the download when the pin is already installed ------------
# --version prints the bare version on stdout and decorative art on stderr.
installed="$("$DEST/dcg" --version 2>/dev/null | head -n1 || true)"
if [ "$installed" = "${DCG_VERSION#v}" ]; then
  echo "ok    dcg $installed (pinned)"
  exit 0
fi

if ! command -v curl >/dev/null; then
  echo "note: need 'curl' to fetch dcg; skipping binary install"
  exit 1
fi

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)  target="aarch64-apple-darwin" ;;
  Darwin-x86_64) target="x86_64-apple-darwin" ;;
  Linux-x86_64)  target="x86_64-unknown-linux-musl" ;;
  Linux-aarch64) target="aarch64-unknown-linux-gnu" ;;
  *)
    echo "note: no dcg release artifact for $(uname -s)/$(uname -m); skipping"
    exit 1
    ;;
esac

# macOS bsdtar decompresses .xz natively; GNU tar shells out to xz.
if [ "$(uname -s)" = "Linux" ] && ! command -v xz >/dev/null; then
  echo "note: need 'xz' to unpack dcg on Linux (apt install xz-utils); skipping"
  exit 1
fi

tarball="dcg-${target}.tar.xz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "fetch  $tarball ($DCG_VERSION)"
curl -fsSL --proto '=https' --retry 3 -o "$tmp/$tarball"        "$BASE_URL/$tarball"
curl -fsSL --proto '=https' --retry 3 -o "$tmp/$tarball.sha256" "$BASE_URL/$tarball.sha256"

# sha256 (mandatory). The sidecar is "<hex>  <filename>"; compare the hex field
# directly so the check is identical under macOS shasum and Linux sha256sum
# regardless of the local filename.
expected="$(awk 'NR==1 {print tolower($1)}' "$tmp/$tarball.sha256")"
case "$expected" in
  *[!0-9a-f]* | "")
    echo "error: malformed sha256 sidecar for $tarball"
    exit 1
    ;;
esac
if [ "${#expected}" -ne 64 ]; then
  echo "error: malformed sha256 sidecar for $tarball"
  exit 1
fi
if command -v sha256sum >/dev/null; then
  actual="$(sha256sum "$tmp/$tarball" | awk '{print $1}')"
else
  actual="$(shasum -a 256 "$tmp/$tarball" | awk '{print $1}')"
fi
if [ "$actual" != "$expected" ]; then
  echo "error: sha256 mismatch for $tarball"
  echo "  expected $expected"
  echo "  got      $actual"
  exit 1
fi
echo "ok     sha256 verified"

# minisign: verified whenever the tool is present (a bad signature is fatal);
# a missing tool just notes and moves on -- sha256 already passed, and the
# Brewfile installs minisign on the next provision.
if command -v minisign >/dev/null; then
  curl -fsSL --proto '=https' --retry 3 -o "$tmp/$tarball.minisig" "$BASE_URL/$tarball.minisig"
  minisign -Vqm "$tmp/$tarball" -x "$tmp/$tarball.minisig" -P "$MINISIGN_PUBKEY"
  echo "ok     minisign verified"
else
  echo "note:  minisign not installed; signature not checked (sha256 verified)"
fi

# Extract the single 'dcg' member, then swap into place atomically so a hook
# firing mid-install never sees a partial binary.
tar -xf "$tmp/$tarball" -C "$tmp" dcg
mkdir -p "$DEST"
install -m 0755 "$tmp/dcg" "$DEST/dcg.new.$$"
mv -f "$DEST/dcg.new.$$" "$DEST/dcg"

installed="$("$DEST/dcg" --version 2>/dev/null | head -n1 || true)"
if [ "$installed" != "${DCG_VERSION#v}" ]; then
  echo "error: installed dcg reports '${installed:-nothing}', expected ${DCG_VERSION#v}"
  exit 1
fi
echo "ok     dcg $installed -> $DEST/dcg"
