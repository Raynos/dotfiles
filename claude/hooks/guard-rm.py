#!/usr/bin/env python3
"""PreToolUse guard for destructive rm.

Replaces the Bash(rm -rf ...) deny rules, which could only *prompt* when they
couldn't statically resolve a target -- that is how a background workflow agent
sat blocked for 23h on `rm -rf $S/$d` (2026-07-31).

Contract: this hook only ever ALLOWS (exit 0) or BLOCKS (exit 2). It never asks,
so it can never stall an unattended run. stderr on a block is fed back to Claude.

Policy: block literal targets that are the filesystem root, a home/system dir, a
bare glob, or `.`/`..`. Targets containing an unexpanded $VAR are allowed -- they
cannot be resolved without running the shell, and blocking them is what broke
scripted work in the first place.
"""

import json
import os
import re
import shlex
import sys

HOME = os.path.expanduser("~")

PROTECTED = {
    "/", "/Users", "/etc", "/usr", "/bin", "/sbin", "/var", "/opt",
    "/System", "/Library", "/Applications", "/private", "/tmp",
    HOME,
    os.path.join(HOME, "projects"),
    os.path.join(HOME, ".claude"),
    os.path.join(HOME, ".ssh"),
    os.path.join(HOME, ".config"),
    os.path.join(HOME, "Documents"),
    os.path.join(HOME, "Desktop"),
    os.path.join(HOME, "Downloads"),
    os.path.join(HOME, "Library"),
}

# Bare relative targets that wipe whatever the cwd happens to be.
BAD_RELATIVE = {".", "..", "./", "../", "*", "*/", ".*", "-r", "--"}

SEPARATORS = re.compile(r"(?:\|\||&&|[;\n|&])")


def targets_and_flags(tokens):
    """Split rm's argv into (flags, targets), honouring `--`."""
    flags, targets, end_of_flags = [], [], False
    for tok in tokens:
        if not end_of_flags and tok == "--":
            end_of_flags = True
        elif not end_of_flags and tok.startswith("-") and len(tok) > 1:
            flags.append(tok)
        else:
            targets.append(tok)
    return flags, targets


def is_recursive(flags):
    for f in flags:
        if f.startswith("--"):
            if f in ("--recursive",):
                return True
        elif "r" in f.lower():
            return True
    return False


def verdict(target):
    """Return a block reason for this rm target, or None to allow."""
    t = target.strip().strip("'\"")
    if not t:
        return None

    # Unresolvable without running the shell. Allowing these is deliberate:
    # `rm -rf $S/$d` against a scratchpad is normal agent work.
    if "$" in t or "`" in t:
        return None

    if t in BAD_RELATIVE:
        return f"`rm -r` of {t!r} deletes whatever the cwd happens to be"

    if t.startswith("~"):
        t = HOME + t[1:]

    if not os.path.isabs(t):
        return None

    # `/*` and `/Users/*` are the classic catastrophes: the glob expands to
    # every child, so the parent is what is really being emptied.
    glob_parent = None
    if t.endswith("/*"):
        glob_parent = os.path.normpath(t[:-2]) or "/"

    norm = os.path.normpath(glob_parent or t)

    if norm in PROTECTED:
        what = f"every child of {norm}" if glob_parent else norm
        return f"`rm -r` targeting {what} is a protected path"

    # Anything shallower than 3 components under root (/a/b) is close enough to
    # a system or home root to be a mistake rather than an intent.
    if len([p for p in norm.split("/") if p]) < 3 and norm != "/private/tmp":
        return f"`rm -r` targeting {norm} is too close to the filesystem root"

    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # Never block on a malformed payload.

    if payload.get("tool_name") != "Bash":
        sys.exit(0)

    command = (payload.get("tool_input") or {}).get("command") or ""
    if not re.search(r"\brm\b", command):
        sys.exit(0)

    for segment in SEPARATORS.split(command):
        segment = segment.strip()
        if not segment:
            continue
        try:
            tokens = shlex.split(segment, comments=True)
        except ValueError:
            continue  # Unbalanced quotes (heredoc fragment); nothing to judge.

        # Skip leading env assignments and wrappers so `sudo rm` / `env X=1 rm`
        # are still inspected.
        while tokens and (
            re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", tokens[0])
            or tokens[0] in ("sudo", "env", "command", "nohup", "time", "then", "do")
        ):
            tokens.pop(0)

        if not tokens or os.path.basename(tokens[0]) != "rm":
            continue

        flags, targets = targets_and_flags(tokens[1:])
        if not is_recursive(flags):
            continue

        for target in targets:
            reason = verdict(target)
            if reason:
                print(
                    f"Blocked by guard-rm hook: {reason}.\n"
                    f"Offending command: {segment}\n"
                    "If this is genuinely intended, ask the user to run it manually.",
                    file=sys.stderr,
                )
                sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
