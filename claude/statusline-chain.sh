#!/bin/bash
# Render the normal status line (ccstatusline) from inside a repo that ships its
# own statusLine.
#
# A project's checked-in .claude/settings.json outranks ~/.claude/settings.json,
# so a repo that sets statusLine replaces ours for every session started there.
# depscan does: its tools/claude-usage-statusline-shim.sh caches plan usage and
# then prints a bare "<model> — <cwd>", unless CLAUDE_STATUSLINE_CHAIN names a
# script, in which case it pipes the payload to `bash <that script>` instead.
#
# settings.managed.json sets CLAUDE_STATUSLINE_CHAIN to this file. The shim
# needs a real file path (it tests -f), which is why this wrapper exists rather
# than pointing the variable at the `ccstatusline` command name.
exec ccstatusline
