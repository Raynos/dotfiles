# (`set +h` used to be here — see the note at the top of ~/.bashrc for why
# disabling bash's command hash table was a bad idea on a 45-entry PATH.)

# ABOVE the interactivity guard on purpose. bash reads this file INSTEAD of
# .profile, so a non-interactive login bash (`bash -lc`, a hook, a script) that
# returns at the next line never reaches .bashrc, .path, or .profile — and so
# never gets bun on PATH. That is what made `omp` "not found" everywhere except
# a terminal a human had typed into. Keep this cheap and side-effect free.
export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && export PATH="$BUN_INSTALL/bin:$PATH"

# Node's compile cache defaults to $TMPDIR/node-compile-cache, and macOS empties
# $TMPDIR at boot before login: 110k cache files there on 2026-10-15, after
# millions of leftover export files had held the laptop at the login bar for
# hours. A persistent cache folder survives reboots and costs boot nothing.
export NODE_COMPILE_CACHE="$HOME/Library/Caches/node-compile-cache"

# Compact Claude Code sessions at 400k tokens instead of near the 1M window
# (wildshard meta AUTO-COMPACT-TRIAL-PLAN, Jake 2026-11-12). The same value is in
# claude/settings.managed.json "env"; this copy covers anything that reads the
# shell env before Claude Code loads its settings. Change both together.
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=400000

[[ $- == *i* ]] || return 0

# test if the prompt var is not set
if [ -z "$PS1" ]; then
    # prompt var is not set, so this is *not* an interactive shell
    return
fi

# Run the .bashrc
if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi

# .bashrc already deduped PATH, but this file appends after sourcing it (and an
# inherited PATH may already contain these). Run it once more, last.
declare -F __dedupe_path >/dev/null && __dedupe_path
