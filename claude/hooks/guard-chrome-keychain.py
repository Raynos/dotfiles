#!/usr/bin/env python3
"""PreToolUse (Claude Code + Codex) guard: refuse a shell command that launches a Chromium / Chrome for Testing
binary by hand without --use-mock-keychain and --password-store=basic (macOS "Safe Storage" keychain dialog), or
that drops Playwright's defaults with ignoreDefaultArgs. Exit 2 + stderr = block. Fails open on any parse error.
Scripts run by name (node x.mjs) are not read here; repo static checks cover those. Undo: remove the hook entry."""
import json, re, sys

FLAGS = ("--use-mock-keychain", "--password-store=basic")
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
    sys.stderr.write("BLOCKED (keychain dialog): " + why + ". Every Chromium launch passes --use-mock-keychain and "
                     "--password-store=basic; use Playwright launch() defaults, never ignoreDefaultArgs.\n")
    sys.exit(2)
