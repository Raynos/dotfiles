#!/usr/bin/env python3
"""Tests for guard-rm.py: run `python3 claude/hooks/test_guard_rm.py`.

Each case feeds a PreToolUse payload on stdin and checks the exit code
(0 = allow, 2 = block). The hook must never ask.
"""

import json
import os
import subprocess
import sys

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "guard-rm.py")
CWD = "/Users/raynos/projects/games/wildshard-singleplayer"

CASES = [
    # 2026-10-08: the command that stalled the shard-platform coordinator on the built-in ask.
    ('tmp=$(cd "$(mktemp -d /private/tmp/claude-501/sp-builders/hybrid-rows/rc.XXXX)" && pwd -P); '
     'git archive HEAD | tar -x -C "$tmp"; rm -rf $tmp', 2),
    ('tmp="$(mktemp -d)"; do_work "$tmp"; rm -rf "$tmp"', 2),
    ('d=`mktemp -d`; rm -rf ${d}', 2),
    # Still allowed: variables not assigned from a substitution, literal paths, scratch subpaths.
    ('rm -rf $S/$d', 2),  # variable-rooted path: the 2026-09-13 built-in mirror, unchanged
    ('rm -rf "$SCRATCH"', 0),
    ('rm -rf /private/tmp/claude-501/sp-builders/hybrid-rows/rc.AbC1', 0),
    ('rm -f progress/tmp/a.jpg progress/tmp/b.jpg', 0),
    # Still blocked: the existing shapes.
    ('rm -rf $TMP/', 2),
    ('rm -rf /', 2),
    ('rm -rf ~', 2),
]


def run(command):
    payload = {"tool_name": "Bash", "tool_input": {"command": command}, "cwd": CWD}
    p = subprocess.run([sys.executable, HOOK], input=json.dumps(payload), capture_output=True, text=True)
    return p.returncode, p.stderr


def main():
    failed = 0
    for command, want in CASES:
        got, err = run(command)
        ok = got == want
        failed += not ok
        print(f"{'ok  ' if ok else 'FAIL'} exit {got} (want {want}): {command[:90]}")
        if not ok and err:
            print("     " + err.strip().splitlines()[0])
    print(f"{len(CASES) - failed}/{len(CASES)} passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
