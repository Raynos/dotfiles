#!/usr/bin/env node

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const arguments_ = process.argv.slice(2);
const check = arguments_.includes("--check");
const target = arguments_.find((argument) => argument !== "--check") ??
  join(process.env.HOME, ".codex", "config.toml");
const managedSource = readFileSync(join(root, "config.managed.toml"), "utf8");
const managed = managedSource.split(/^\[tools(?:\.|\])/m, 1)[0]
  .split("\n")
  .filter((line) => /^[a-z_]+\s*=/.test(line));
const source = existsSync(target) ? readFileSync(target, "utf8") : "";
const firstTable = source.search(/^\[/m);
let actual = firstTable === -1 ? source : source.slice(0, firstTable);
let tables = firstTable === -1 ? "" : source.slice(firstTable);
let changed = false;

for (const line of managed) {
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

for (const line of managed) {
  const [key] = line.split("=", 1);
  const matcher = new RegExp(`^${key}\\s*=.*\\n?`, "gm");
  if (matcher.test(tables)) {
    tables = tables.replace(matcher, "");
    changed = true;
  }
}

actual += tables;

const requestTable = "[tools.experimental_request_user_input]";
const enabled = "enabled = true";
const requestMatcher = /^\[tools\.experimental_request_user_input\]\s*$/m;
const staleBoolean = /^experimental_request_user_input\s*=.*\n?/m;
if (requestMatcher.test(actual)) {
  const start = actual.search(requestMatcher);
  const after = actual.slice(start);
  const nextTable = after.slice(1).search(/^\[/m);
  const end = nextTable === -1 ? actual.length : start + nextTable + 1;
  const section = actual.slice(start, end);
  const key = /^enabled\s*=.*$/m;
  if (!key.test(section) || section.match(key)[0] !== enabled) {
    const nextSection = key.test(section)
      ? section.replace(key, enabled)
      : `${section.endsWith("\n") ? section : `${section}\n`}${enabled}\n`;
    actual = `${actual.slice(0, start)}${nextSection}${actual.slice(end)}`;
    changed = true;
  }
} else {
  if (staleBoolean.test(actual)) {
    actual = actual.replace(staleBoolean, "");
    changed = true;
  }
  actual += `${actual.endsWith("\n") || actual.length === 0 ? "" : "\n"}${requestTable}\n${enabled}\n`;
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
