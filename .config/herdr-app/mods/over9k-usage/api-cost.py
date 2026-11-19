#!/usr/bin/env python3
# Claude billed by use (Amazon Bedrock, Vertex, Foundry, an API key): what it cost by day
# and by model, for the Usage rows.
# Claude Code gives a status line one total per session and saves cost by model only
# when a session ends, so this works it out from the transcripts: each API call's
# tokens at list prices, the same sum /usage shows. An estimate, not the bill; a cloud's
# prices can differ, and Claude Code's own background calls aren't in transcripts. Runs on
# the computer whose Claude it is; prints nothing unless that Claude is billed by use
# (claude.json, saved by Over9k's status line). Parsed files are kept in a cache, so a
# refresh is cheap.
import datetime, json, os, re, sys

DAYS = 30
VERSION = 2  # Bump when prices change: the cache holds costs.
# Dollars per million tokens: input, output, cache read. A cache write is 1.25x input
# for 5 minutes, 2x for an hour.
PRICES = {
    "Fable 5.1": (10, 50, 0.25), "Fable 5": (10, 50, 1), "Opus 5.5": (4, 20, 0.2),
    "Opus 5": (5, 25, 0.5), "Sonnet 5.5": (2, 10, 0.2), "Sonnet 5": (2, 10, 0.2),
    "Sonnet 4.6": (3, 15, 0.3), "Haiku 5.5": (0.1, 0.5, 0.01), "Haiku 4.5": (1, 5, 0.1),
}
# A model not listed: its family's usual price.
FAMILY = {"fable": (10, 50, 1), "opus": (5, 25, 0.5), "sonnet": (3, 15, 0.3), "haiku": (1, 5, 0.1)}


def model_name(mid):
    # "claude-opus-5-5" -> "Opus 5.5"; Bedrock's "us.anthropic.claude-opus-5-5-v1:0" too.
    m = re.search(r"claude-([a-z]+)-(\d+)(?:-(\d{1,2}))?(?![\d])", mid or "")
    if not m:
        return None
    return f"{m.group(1).capitalize()} {m.group(2)}{'.' + m.group(3) if m.group(3) else ''}"


def cost(name, u):
    p = PRICES.get(name) or FAMILY.get(name.split()[0].lower())
    if not p:
        return None
    c = u.get("cache_creation") or {}
    hour = c.get("ephemeral_1h_input_tokens") or 0
    five = max((u.get("cache_creation_input_tokens") or 0) - hour, 0)
    # Fast mode (the Claude API only) is twice the price.
    return (2 if u.get("speed") == "fast" else 1) * (
        (u.get("input_tokens") or 0) * p[0] + (u.get("output_tokens") or 0) * p[1]
        + (u.get("cache_read_input_tokens") or 0) * p[2]
        + five * p[0] * 1.25 + hour * p[0] * 2) / 1e6


def read_transcript(path):
    # Each API call once, by its id ({id: [day, model, cost]}): it spans several lines.
    calls = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if '"type":"assistant"' not in line:
                continue
            try:
                d = json.loads(line)
                m = d.get("message") or {}
                name, use = model_name(m.get("model")), m.get("usage")
                if d.get("type") != "assistant" or not name or not use:
                    continue
                at = datetime.datetime.fromisoformat(d["timestamp"].replace("Z", "+00:00"))
                c = cost(name, use)
                if c is not None:
                    calls[d.get("requestId") or d.get("uuid")] = [at.astimezone().strftime("%Y-%m-%d"), name, round(c, 7)]
            except (ValueError, KeyError, TypeError, AttributeError):
                continue
    return calls


def scan(root, cutoff, cache):
    # Every transcript, subagents' too, changed since cutoff; the cache for those unchanged.
    files = {}
    for folder, _dirs, names in os.walk(root):
        for n in names:
            if not n.endswith(".jsonl"):
                continue
            p = os.path.join(folder, n)
            try:
                s = os.stat(p)
            except OSError:
                continue
            if s.st_mtime < cutoff:
                continue
            old = cache.get(p)
            if old and old[0] == s.st_mtime and old[1] == s.st_size:
                files[p] = old
                continue
            try:
                files[p] = [s.st_mtime, s.st_size, read_transcript(p)]
            except OSError:
                pass
    return files


def main():
    home = os.path.expanduser("~")
    usage = os.path.join(home, ".cache", "over9k", "usage")
    try:
        with open(os.path.join(usage, "claude.json")) as f:
            saved = json.load(f)
        # "bedrock": what status lines from before other kinds of billing wrote.
        plan = saved.get("api") or ("Bedrock" if saved.get("bedrock") else None)
        if not plan:
            return
    except (OSError, ValueError):
        return
    store = os.path.join(usage, "api-cost-cache.json")
    try:
        with open(store) as f:
            saved = json.load(f)
        cache = saved["files"] if saved.get("v") == VERSION else {}
    except (OSError, ValueError, KeyError):
        cache = {}
    now = datetime.datetime.now()
    days = [(now - datetime.timedelta(days=i)).strftime("%Y-%m-%d") for i in range(DAYS - 1, -1, -1)]
    # A resumed chat copies its history into a new file: one count per call across files.
    files = scan(os.path.join(home, ".claude", "projects"), now.timestamp() - (DAYS + 1) * 86400, cache)
    calls = {}
    for f in files.values():
        calls.update(f[2])
    by_day = {d: {} for d in days}
    for day, name, c in calls.values():
        if day in by_day:
            by_day[day][name] = by_day[day].get(name, 0) + c
    tmp = f"{store}.{os.getpid()}"
    try:
        with open(tmp, "w") as f:
            json.dump({"v": VERSION, "files": files}, f, separators=(",", ":"))
        os.replace(tmp, store)
    except OSError:
        pass
    json.dump({"plan": plan, "days": [{"day": d, "models": {n: round(c, 6) for n, c in by_day[d].items()}} for d in days]}, sys.stdout)


if __name__ == "__main__":
    main()
