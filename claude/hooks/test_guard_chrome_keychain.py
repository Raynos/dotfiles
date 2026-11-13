import json, subprocess, pathlib, sys
H = str(pathlib.Path(__file__).with_name("guard-chrome-keychain.py"))
BIN = '"/U/Library/Caches/ms-playwright/chromium-1254/Google Chrome for Testing"'
CASES = [
    (BIN + " --headless=new --user-data-dir=/tmp/p", 2),
    (BIN + " --headless=new --user-data-dir=/tmp/p --use-mock-keychain --password-store=basic --mute-audio", 0),
    (BIN + " --headless=new --user-data-dir=/tmp/p --use-mock-keychain --password-store=basic", 2),
    (BIN + " --headless=new --mute-audio", 2),
    (BIN + " --headless=new --use-mock-keychain", 2),
    ('node -e "chromium.launch({ignoreDefaultArgs:true})"', 2),
    ('node -e "spawn(chromium.executablePath(),[\'--headless\'])"', 2),
    ('grep -rn ignoreDefaultArgs scripts', 0),
    ('ps aux | grep "Google Chrome for Testing" | grep headless', 0),
    ('git commit -m "ms-playwright --headless"', 0),
    ('cd /x; git log -1; grep -rn ignoreDefaultArgs scripts', 0),
    ('node scripts/foo.mjs', 0),
    ('agent-browser open http://localhost:3000', 0),
    ('agent-browser --args "--use-angle=metal" open http://localhost:3000', 2),
    ('AGENT_BROWSER_ARGS=--use-angle=metal agent-browser open http://localhost:3000', 2),
    ('agent-browser --args "--mute-audio,--use-angle=metal" open http://localhost:3000', 0),
    ('grep -n -- --args ~/.agent-browser/config.json; agent-browser open about:blank', 0),
    ('export AGENT_BROWSER_ARGS=--use-angle=metal', 2),
    ('python3 -c "print(1)" # an agent-browser --args override must keep the mute', 0),
]
bad = 0
for cmd, want in CASES:
    p = subprocess.run([sys.executable, H], input=json.dumps({"tool_input": {"command": cmd}}), text=True, capture_output=True)
    ok = p.returncode == want
    bad += not ok
    print("ok  " if ok else "FAIL", p.returncode, cmd[:70])
sys.exit(1 if bad else 0)
