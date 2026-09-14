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

Second job (2026-09-13): pre-empt Claude Code's built-in `dangerousRemoval`
safety check. That check is bypass-immune (fires under bypassPermissions, cannot
be allow-ruled, ignores a hook "allow") and its only output is an interactive
*ask* -- exactly the dialog that stalls an overnight agent. Sessions run in
`dontAsk` mode so the ask becomes a deny, but a dontAsk deny carries no reason
and the agent just retries the same shape. So this hook denies the same target
shapes first, with a message that says how to rewrite the command. This applies
to every rm/rmdir, recursive or not. Shapes mirrored from the 2.1.270 binary:

  - relative `dir/*` when the command also contains cd/pushd/popd
  - `$VAR/...`, `"$VAR"/*`, `${VAR:-x}/...`: variable-rooted (possibly empty)
  - `~/dir/*`, `../dir/*`, or any unexpanded `$` in a `dir/*` target
  - globs in a directory component, or more than one glob level (`a/*/*`)
  - the working directory itself or one of its ancestors
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


VAR_ROOTED = re.compile(
    r"""^["']*\$(?:\{[A-Za-z_@*!#0-9][A-Za-z0-9_]*(?::?-[^}]*)?\}|[A-Za-z_@*!#0-9][A-Za-z0-9_]*)["']*/(?:[*?\[{]|\$|/|["']|$)"""
)
CD_COMMANDS = {"cd", "pushd", "popd", "chdir"}


def unresolvable(cmd, target, saw_cd, cwd):
    """Reason the built-in dangerousRemoval check would *ask* about `target`.

    Returns None when the target is statically resolvable and therefore never
    reaches a permission dialog.
    """
    t = target
    ends_glob = bool(re.search(r"/\*+$", t))
    is_abs = t.startswith("/")

    if VAR_ROOTED.match(t):
        return f"{t!r} is rooted at a shell variable that may be empty or unset"

    if ends_glob:
        if saw_cd and not is_abs:
            return f"{t!r} is a relative glob after a cd in the same command"
        if t.startswith("~"):
            return f"{t!r} is a `~`-rooted glob (the tilde is not expanded statically)"
        if "$" in t:
            return f"{t!r} mixes an unexpanded variable into a glob target"
        if not is_abs and re.search(r"(^|/)\.\.(/|$)", t):
            return f"{t!r} walks up through `..` before a glob"
        stem = re.sub(r"(/\*+)+/*$", "", t)
        if re.search(r"[*?\[]", stem):
            return f"{t!r} has a wildcard in a directory component"
        if len(re.findall(r"/\*+", t[len(stem):])) > 1:
            return f"{t!r} globs more than one directory level"

    # Workspace: the cwd or any ancestor of it.
    if cwd and not re.search(r"[*?\[$~]", t):
        resolved = os.path.normpath(t if is_abs else os.path.join(cwd, t))
        cwd_n = os.path.normpath(cwd)
        if resolved == cwd_n or cwd_n.startswith(resolved.rstrip("/") + "/"):
            return f"{t!r} is the working directory or one of its ancestors"

    return None


# Suggest only idioms that BOTH guards accept: dcg denies absolute rm globs under
# $HOME and `find -delete`, Claude Code denies relative globs after a cd.
UNRESOLVABLE_HELP = (
    "Claude Code's built-in rm check cannot resolve this target statically and "
    "would stall on a permission dialog. Rewrite it as one of:\n"
    "  - `find /abs/dir -mindepth 1 -maxdepth 1 -type f -exec rm -f {} +`\n"
    "  - a relative `rm -f sub/*` issued as its own command, with the shell "
    "already in that directory (no cd, no $VAR, no ~, no .. in the same command)\n"
    "  - explicit file names: `rm -f /abs/dir/a.mp4 /abs/dir/b.mp4`"
)


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # Never block on a malformed payload.

    if payload.get("tool_name") != "Bash":
        sys.exit(0)

    command = (payload.get("tool_input") or {}).get("command") or ""
    if not re.search(r"\brm(dir)?\b", command):
        sys.exit(0)
    cwd = payload.get("cwd") or os.getcwd()

    saw_cd = False
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

        if not tokens:
            continue
        cmd = os.path.basename(tokens[0])
        if cmd in CD_COMMANDS:
            saw_cd = True
            continue
        if cmd not in ("rm", "rmdir"):
            continue

        flags, targets = targets_and_flags(tokens[1:])

        for target in targets:
            reason = unresolvable(cmd, target, saw_cd, cwd)
            if reason:
                print(
                    f"Blocked by guard-rm hook: {reason}.\n"
                    f"Offending command: {segment}\n{UNRESOLVABLE_HELP}",
                    file=sys.stderr,
                )
                sys.exit(2)

        if cmd != "rm" or not is_recursive(flags):
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
