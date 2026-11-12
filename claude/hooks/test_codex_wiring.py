import json, os, subprocess
c = json.load(open(os.path.expanduser('~/.codex/hooks.json')))['hooks']['PreToolUse'][-1]['hooks'][0]['command']
for cmd, want in [('"/x/ms-playwright/c/Google Chrome for Testing" --headless', 2), ('ls', 0)]:
    p = subprocess.run(['bash', '-c', c], input=json.dumps({'tool_input': {'command': cmd}}), text=True, capture_output=True)
    print(p.returncode == want, p.returncode, c)
