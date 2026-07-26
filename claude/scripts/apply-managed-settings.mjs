#!/usr/bin/env node
//
// Merge this repo's managed Claude Code settings into ~/.claude/settings.json.
//
// settings.json is APP-WRITTEN: Claude Code rewrites it whenever you switch
// model, toggle a plugin, or change notification channel. That rules out both
// of the ways this repo normally tracks a file:
//
//   - Symlinking it. The app writes atomically (temp file + rename), which
//     replaces the symlink with a regular file rather than writing through it.
//     That is exactly what happened here — see the .dotfiles-backup-* dirs in
//     ~/.claude, where install.sh had to re-link settings.json twice.
//   - Copying it wholesale. The repo and the app would then fight over model,
//     theme and enabledPlugins every time either side changed.
//
// So the repo owns a SUBSET of top-level keys — the infrastructure ones that
// wire Claude Code up to this repo's scripts, plus the permission rules — and
// the app keeps ownership of everything else. Managed keys are replaced
// wholesale; unmanaged keys are never touched, so app state survives.
//
// Same shape as codex/scripts/apply-managed-config.mjs.
//
// Usage:
//   node apply-managed-settings.mjs [target]   merge in place (idempotent)
//   node apply-managed-settings.mjs --check    exit 1 if a merge is needed
//
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const arguments_ = process.argv.slice(2);
const check = arguments_.includes("--check");
const target = arguments_.find((argument) => argument !== "--check") ??
  join(process.env.HOME, ".claude", "settings.json");

const managed = JSON.parse(readFileSync(join(root, "settings.managed.json"), "utf8"));
const current = existsSync(target) ? JSON.parse(readFileSync(target, "utf8")) : {};

// Spreading first keeps existing keys in their existing positions; only genuinely
// new managed keys get appended, so the diff stays small and reviewable.
const merged = { ...current };
const changed = [];

for (const [key, value] of Object.entries(managed)) {
  if (JSON.stringify(current[key]) !== JSON.stringify(value)) {
    merged[key] = value;
    changed.push(key);
  }
}

if (changed.length === 0) {
  console.log(`ok     ${target} (managed keys already match)`);
  process.exit(0);
}

if (check) {
  console.error(`drift  ${target}: ${changed.join(", ")}`);
  console.error(`       run: node ${process.argv[1].replace(process.env.HOME, "~")}`);
  process.exit(1);
}

writeFileSync(target, `${JSON.stringify(merged, null, 2)}\n`);
console.log(`apply  ${target}: ${changed.join(", ")}`);
