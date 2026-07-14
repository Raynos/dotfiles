#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(readFileSync(join(root, "tooling.json"), "utf8"));
const mode = process.argv[2] ?? "check";

if (!["check", "install"].includes(mode)) {
  console.error("usage: sync-agent-tooling.mjs {check|install}");
  process.exit(2);
}

function run(command, args) {
  try {
    return {
      ok: true,
      output: execFileSync(command, args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] })
    };
  } catch (error) {
    return {
      ok: false,
      output: `${error.stdout ?? ""}${error.stderr ?? ""}`.trim()
    };
  }
}

function codexMcpMatches(capability) {
  const result = run("codex", ["mcp", "get", capability.name]);
  if (!result.ok) return false;
  const { command, args } = capability.codex;
  return result.output.includes(`command: ${command}`) &&
    args.every((arg) => result.output.includes(arg));
}

function codexPluginInstalled(capability) {
  const result = run("codex", ["plugin", "list"]);
  return result.ok && result.output.includes(`${capability.codex.id} `) &&
    result.output.includes("installed, enabled");
}

function claudePluginInstalled(capability, plugins) {
  return plugins.some((plugin) => plugin.id === capability.claude.id && plugin.enabled);
}

function claudePlugins() {
  const result = run("claude", ["plugin", "list", "--json"]);
  if (!result.ok) return [];
  try {
    return JSON.parse(result.output);
  } catch {
    return [];
  }
}

const installedClaudePlugins = claudePlugins();
let failures = 0;

for (const capability of manifest.capabilities) {
  if (capability.claude) {
    const present = claudePluginInstalled(capability, installedClaudePlugins);
    console.log(`${present ? "ok" : "MISSING"} Claude ${capability.name} (${capability.claude.kind})`);
    if (!present) failures += 1;
  }

  if (!capability.codex) continue;

  let present = capability.codex.kind === "mcp"
    ? codexMcpMatches(capability)
    : codexPluginInstalled(capability);

  if (!present && mode === "install" && capability.codex.kind === "mcp") {
    const result = run("codex", [
      "mcp", "add", capability.name, "--", capability.codex.command, ...capability.codex.args
    ]);
    if (!result.ok) {
      console.error(result.output);
    }
    present = result.ok && codexMcpMatches(capability);
  }

  console.log(`${present ? "ok" : "MISSING"} Codex ${capability.name} (${capability.codex.kind})`);
  if (!present) failures += 1;
}

if (failures > 0) {
  console.error(`\n${failures} required capability/capabilities missing.`);
  process.exit(1);
}
