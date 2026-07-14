#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = dirname(fileURLToPath(import.meta.url));
const manifestPath = join(root, "tooling.json");
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
const mode = process.argv[2] ?? "check";

if (!["check", "export", "install"].includes(mode)) {
  console.error("usage: sync-agent-tooling.mjs {check|export|install}");
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

function codexMcp(name) {
  const result = run("codex", ["mcp", "get", name, "--json"]);
  if (!result.ok) return null;
  try {
    const transport = JSON.parse(result.output).transport;
    return transport?.type === "stdio" ? transport : null;
  } catch {
    return null;
  }
}

function codexMcpMatches(capability) {
  const actual = codexMcp(capability.name);
  return actual?.command === capability.codex.command &&
    JSON.stringify(actual.args) === JSON.stringify(capability.codex.args);
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
const exportedCapabilities = [];

for (const capability of manifest.capabilities) {
  if (capability.claude) {
    const present = claudePluginInstalled(capability, installedClaudePlugins);
    console.log(`${present ? "ok" : "MISSING"} Claude ${capability.name} (${capability.claude.kind})`);
    if (!present) failures += 1;
  }

  if (!capability.codex) {
    exportedCapabilities.push(capability);
    continue;
  }

  let present = capability.codex.kind === "mcp"
    ? codexMcpMatches(capability)
    : codexPluginInstalled(capability);

  if (!present && mode === "install") {
    const result = capability.codex.kind === "mcp"
      ? run("codex", [
          "mcp", "add", capability.name, "--", capability.codex.command,
          ...capability.codex.args
        ])
      : run("codex", ["plugin", "add", capability.codex.id]);
    if (!result.ok) {
      console.error(result.output);
    }
    present = result.ok && (capability.codex.kind === "mcp"
      ? codexMcpMatches(capability)
      : codexPluginInstalled(capability));
  }

  console.log(`${present ? "ok" : "MISSING"} Codex ${capability.name} (${capability.codex.kind})`);
  if (!present) failures += 1;

  if (mode === "export") {
    if (capability.codex.kind === "mcp") {
      const actual = codexMcp(capability.name);
      if (actual) {
        exportedCapabilities.push({
          ...capability,
          codex: { kind: "mcp", command: actual.command, args: actual.args }
        });
      }
    } else {
      exportedCapabilities.push(capability);
    }
  }
}

if (failures > 0) {
  console.error(`\n${failures} required capability/capabilities missing.`);
  process.exit(1);
}

if (mode === "export") {
  writeFileSync(manifestPath, `${JSON.stringify({
    version: manifest.version,
    capabilities: exportedCapabilities
  }, null, 2)}\n`);
  console.log(`exported ${exportedCapabilities.length} credential-free capabilities`);
}
