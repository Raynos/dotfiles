#!/usr/bin/env python3
"""PreToolUse (Claude Code + Codex) guard: refuse a shell command that launches a Chromium / Chrome for Testing
binary by hand without --use-mock-keychain and --password-store=basic (macOS "Safe Storage" keychain dialog) or
without --mute-audio (Jake, 2026-11-13: "headless chromium with volume off"), or that drops Playwright's defaults
with ignoreDefaultArgs. agent-browser is muted by its config's "args" (dotfiles agent-browser/config.json); a command
that overrides them with --args or AGENT_BROWSER_ARGS must keep --mute-audio. Exit 2 + stderr = block. Fails open on
any parse error. Scripts run by name (node x.mjs) are not read here; repo static checks cover those.
Undo: remove the hook entry."""
import json, re, sys

FLAGS = ("--use-mock-keychain", "--password-store=basic", "--mute-audio")
BROWSER = re.compile(r"ms-playwright|agent-browser/browsers|Google Chrome for Testing|chrome-headless-shell|"
                     r"executablePath\(\)|Chromium\.app|/chromium\b", re.I)
LAUNCH = re.compile(r"--user-data-dir|--remote-debugging-port|--headless|launchPersistentContext|\bspawn\(|"
                    r"\bexecFile(Sync)?\(|\blaunchServer\(")
READONLY = re.compile(r"^\s*(?:sudo\s+)?(?:grep|egrep|rg|ps|ls|cat|sed|awk|head|tail|find|git|pkill|kill|pgrep|wc|echo|"
                      r"printf|open\s+-R|stat|du|rm|mv|cp|tee|test|\[)\b")


def verdict(cmd):
    # judge only segments that are not read-only commands (grep, ps, git ...), so `cd x; grep ignoreDefaultArgs` passes
    cmd = "\n".join(s for s in re.split(r"[;\n]|&&|\|\||\|", cmd) if not READONLY.match(s))
    if re.search(r"ignoreDefaultArgs", cmd):
        return "ignoreDefaultArgs drops Playwright's --use-mock-keychain/--password-store=basic"
    for seg in cmd.split("\n"):
        # only a segment that runs agent-browser or sets its args variable, so prose in a message never matches
        runs = re.match(r"\s*(?:export\s+)?(?:\w+=\S*\s+)*(?:npx\s+)?agent-browser\b", seg)
        sets = re.match(r"\s*(?:export\s+)?(?:\w+=\S*\s+)*AGENT_BROWSER_ARGS=", seg)
        if (runs and re.search(r"(?:^|\s)--args\b|\bAGENT_BROWSER_ARGS=", seg) or sets) and "--mute-audio" not in seg:
            return "agent-browser --args / AGENT_BROWSER_ARGS replaces the config's --mute-audio and lacks it"
    if not (BROWSER.search(cmd) and LAUNCH.search(cmd)):
        return None
    missing = [f for f in FLAGS if f not in cmd]
    return ("browser launch without " + " and ".join(missing)) if missing else None


try:
    data = json.load(sys.stdin)
    cmd = (data.get("tool_input") or {}).get("command") or ""
    why = verdict(cmd) if isinstance(cmd, str) else None
except Exception:
    sys.exit(0)
if why:
    sys.stderr.write("BLOCKED (keychain dialog / sound): " + why + ". Every Chromium launch passes "
                     "--use-mock-keychain, --password-store=basic and --mute-audio (Jake, 2026-11-13: headless "
                     "Chromium with volume off); keep Playwright launch() defaults, never ignoreDefaultArgs.\n")
    sys.exit(2)
