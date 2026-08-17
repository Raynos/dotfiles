#!/usr/bin/env node
//
// Merge this repo's managed Codex config into ~/.codex/config.toml.
//
// config.toml is APP-WRITTEN (Codex adds marketplaces, plugin state, project
// trust, hook trust hashes), so the repo owns only what config.managed.toml
// declares:
//
//   - top-level scalar lines: replaced in place (or appended before the
//     first table), and removed from app-owned tables if duplicated there
//   - [table] sections: replaced wholesale up to the next section header
//     (or appended). Subtables like [tui.model_availability_nux] are their
//     own sections and are NOT touched by managing [tui].
//
// Everything not declared stays exactly as Codex left it.
//
// Same shape as claude/scripts/apply-managed-settings.mjs.
//
// Usage:
//   node apply-managed-config.mjs [target]   merge in place (idempotent)
//   node apply-managed-config.mjs --check    exit 1 if a merge is needed
//
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const arguments_ = process.argv.slice(2);
const check = arguments_.includes("--check");
const target = arguments_.find((argument) => argument !== "--check") ??
  join(process.env.HOME, ".codex", "config.toml");

const managedSource = readFileSync(join(root, "config.managed.toml"), "utf8");
const firstManagedTable = managedSource.search(/^\[/m);
const managedScalars = (firstManagedTable === -1
  ? managedSource
  : managedSource.slice(0, firstManagedTable))
  .split("\n")
  .filter((line) => /^[a-z_]+\s*=/.test(line));
const managedSections = firstManagedTable === -1 ? [] :
  managedSource.slice(firstManagedTable).split(/^(?=\[)/m).map((part) => ({
    header: part.slice(0, part.search(/\r?\n|$/)),
    text: part.trimEnd(),
  }));

const source = existsSync(target) ? readFileSync(target, "utf8") : "";
const firstTable = source.search(/^\[/m);
let actual = firstTable === -1 ? source : source.slice(0, firstTable);
let tables = firstTable === -1 ? "" : source.slice(firstTable);
let changed = false;

for (const line of managedScalars) {
  const [key] = line.split("=", 1);
  const matcher = new RegExp(`^${key.replace(/[.*+?^${}()|[\\]\\]/g, "\\$&")}\\s*=.*$`, "m");
  if (matcher.test(actual)) {
    if (actual.match(matcher)[0] !== line) {
      actual = actual.replace(matcher, line);
      changed = true;
    }
  } else {
    actual += `${actual.endsWith("\n") || actual.length === 0 ? "" : "\n"}${line}\n`;
    changed = true;
  }
}

// A managed scalar that Codex once wrote inside a table would shadow or
// duplicate the top-level one; drop such lines from the table region.
for (const line of managedScalars) {
  const [key] = line.split("=", 1);
  const matcher = new RegExp(`^${key}\\s*=.*\\n?`, "gm");
  if (matcher.test(tables)) {
    tables = tables.replace(matcher, "");
    changed = true;
  }
}

actual += tables;

for (const { header, text } of managedSections) {
  const escaped = header.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const headerMatcher = new RegExp(`^${escaped}[ \\t]*$`, "m");
  if (headerMatcher.test(actual)) {
    const start = actual.search(headerMatcher);
    const afterHeader = start + header.length;
    const nextTable = actual.slice(afterHeader).search(/^\[/m);
    const end = nextTable === -1 ? actual.length : afterHeader + nextTable;
    if (actual.slice(start, end).trimEnd() !== text) {
      const tail = end === actual.length ? "\n" : "\n\n";
      actual = `${actual.slice(0, start)}${text}${tail}${actual.slice(end)}`;
      changed = true;
    }
  } else {
    actual = `${actual.trimEnd()}${actual.trim().length === 0 ? "" : "\n\n"}${text}\n`;
    changed = true;
  }
}

// Migration cleanup: the pre-table boolean this option once used.
const staleBoolean = /^experimental_request_user_input\s*=.*\n?/m;
if (staleBoolean.test(actual)) {
  actual = actual.replace(staleBoolean, "");
  changed = true;
}

if (check) {
  if (changed) {
    console.error(`${target} does not match codex/config.managed.toml`);
    process.exit(1);
  }
  console.log(`ok ${target}`);
  process.exit(0);
}

if (changed) writeFileSync(target, actual);
console.log(`${changed ? "updated" : "ok"} ${target}`);
