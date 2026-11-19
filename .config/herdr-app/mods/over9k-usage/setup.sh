#!/bin/sh
# Over9k's setup outside Herdr: what Options' switches turn on and off, and what
# install.sh sets up. Linux, macOS, and Windows through Git Bash.
#   setup.sh status on|off <mods>     Over9k's optional Claude Code status line (yours kept aside)
#   setup.sh agy on|off <mods>        Antigravity's status line and title, the same way
#   setup.sh cleanup                  takes out what earlier versions of Over9k added
#   setup.sh todo on|off <mods>       the to-do rule (CLAUDE.md, AGENTS.md), the `todo`
#                                     command (~/.local/bin) and its hook (UserPromptSubmit)
#   setup.sh default log|sync on|off  Log / Sync for projects that haven't set their own
#   setup.sh check                    what's missing: one line each (none: nothing printed)
# <mods>: Herdr's mods folder (forward slashes on Windows). Claude Code's settings
# are ~/.claude/settings.json; Over9k's own entries are found by a marker in
# their command, so an older one is replaced and no one else's is touched.
set -u
cmd=${1:-} on=${2:-} mods=${3:-}
settings="$HOME/.claude/settings.json"

need_jq() { command -v jq >/dev/null 2>&1 || { echo "Over9k needs jq for this (https://jqlang.org/download/)" >&2; exit 4; }; }

# Claude Code's settings through jq: edit '<filter>' [jq args...].
edit() {
  need_jq
  mkdir -p "$HOME/.claude"; [ -s "$settings" ] || echo '{}' > "$settings"
  filter=$1; shift
  tmp=$(mktemp) || exit 1
  if jq "$@" "$filter" "$settings" > "$tmp" && [ -s "$tmp" ]; then cat "$tmp" > "$settings"; fi
  rm -f "$tmp"
}

# One of Over9k's hooks on or off: hook <on|off> <event> <marker> <command>.
hook() {
  edit '
    .hooks[$ev] = ((.hooks[$ev] // []) | map(.hooks |= map(select((.command // "") | contains($m) | not))) | map(select(.hooks | length > 0)))
    | if $on == "on" then .hooks[$ev] += [{hooks: [{type: "command", command: $c}]}] else . end
    | if .hooks[$ev] == [] then del(.hooks[$ev]) else . end
    | if .hooks == {} then del(.hooks) else . end' \
    --arg on "$1" --arg ev "$2" --arg m "$3" --arg c "$4"
}

case "$cmd" in
  status)
    # Over9k's optional status line (claude-statusline.sh): on puts it in, keeping
    # any other one aside; off puts that back (or removes ours).
    was="$HOME/.claude/.over9k-statusline-was.json"
    ours='test("over9k[^/\"]*/claude-statusline\\.sh")'
    case "$mods" in *claude-statusline.sh) script=$mods ;; *) script="$mods/over9k/claude-statusline.sh" ;; esac
    if [ "$on" = on ]; then
      need_jq
      [ -s "$settings" ] && jq -e "(.statusLine.command // \"\") as \$c | (\$c | length) > 0 and (\$c | $ours | not)" "$settings" >/dev/null 2>&1 \
        && jq '.statusLine' "$settings" > "$was"
      edit '.statusLine = {type: "command", command: $c, refreshInterval: 5}' --arg c "sh \"$script\""
    elif [ -s "$was" ]; then
      edit '.statusLine = $w[0]' --slurpfile w "$was" && rm -f "$was"
    else
      edit "if ((.statusLine.command // \"\") | $ours) then del(.statusLine) else . end"
    fi
    exit 0 ;;
  agy)
    # Antigravity's status line and title (antigravity/agy-statusline.sh and
    # agy-title.sh): its model and context, and Gemini's limits, for Over9k. Any
    # others are kept aside and come back when it's off.
    need_jq
    ad="$HOME/.gemini/antigravity-cli"; as="$ad/settings.json"; was="$ad/.over9k-was.json"
    [ -d "$ad" ] || { echo "Antigravity isn't installed ($ad)" >&2; exit 3; }
    case "$mods" in */antigravity) dir=$mods ;; *) dir="$mods/over9k/antigravity" ;; esac
    [ -s "$as" ] || echo '{}' > "$as"
    ours='((.statusLine.command // "") | test("agy-statusline\\.sh"))'
    aedit() { jq "$@" "$as" > "$as.tmp" && mv "$as.tmp" "$as"; }
    if [ "$on" = on ]; then
      jq -e "(.statusLine != null or .title != null) and ($ours | not)" "$as" >/dev/null 2>&1 && jq '{statusLine, title}' "$as" > "$was"
      aedit --arg s "sh \"$dir/agy-statusline.sh\"" --arg t "sh \"$dir/agy-title.sh\"" \
        '.statusLine = {type: "command", command: $s, stack_with_default: true} | .title = {type: "command", command: $t}'
    elif [ -s "$was" ]; then
      aedit --slurpfile w "$was" 'del(.statusLine, .title) + ($w[0] | with_entries(select(.value != null)))' && rm -f "$was"
    else
      aedit "if $ours then del(.statusLine, .title) else . end"
    fi
    exit 0 ;;
  cleanup)
    # Removed features: next-prompt suggestions' Stop hook, and a status line an
    # earlier Over9k always put in (statusline.sh; yours comes back). The optional
    # one (claude-statusline.sh) is left as it is.
    [ -s "$settings" ] && command -v jq >/dev/null 2>&1 || exit 0
    hook off Stop over9k-prompts/next.py ""
    was="$HOME/.claude/.over9k-statusline-was.json"
    if jq -e '(.statusLine.command // "") | test("over9k[^/\"]*/statusline\\.sh")' "$settings" >/dev/null 2>&1; then
      if [ -s "$was" ]; then edit '.statusLine = $w[0]' --slurpfile w "$was"; else edit 'del(.statusLine)'; fi
      rm -f "$was"
    fi
    exit 0 ;;
  todo)
    t="$mods/over9k-todos/todo.sh"
    [ -f "$t" ] || { echo "No $t" >&2; exit 2; }
    sh "$t" --rule "$on"
    # The `todo` command agents run: a small wrapper (only Over9k's own is ever
    # replaced or removed).
    w="$HOME/.local/bin/todo"
    ours() { grep -q 'over9k todo wrapper' "$w" 2>/dev/null || { [ -L "$w" ] && readlink "$w" | grep -q over9k; }; }
    if [ "$on" = on ]; then
      if [ ! -e "$w" ] || ours; then
        mkdir -p "$HOME/.local/bin" && rm -f "$w" \
          && printf '#!/bin/sh\n# over9k todo wrapper (Options > To-do)\nexec sh "%s" "$@"\n' "$t" > "$w" && chmod +x "$w"
      fi
    elif ours; then rm -f "$w"; fi
    command -v jq >/dev/null 2>&1 && hook "$on" UserPromptSubmit over9k-todos/todo-hook.sh "sh \"$mods/over9k-todos/todo-hook.sh\""
    exit 0 ;;
  default)
    k=$on v=${3:-}
    case "$k:$v" in log:on|log:off|sync:on|sync:off) ;; *) echo "usage: setup.sh default log|sync on|off" >&2; exit 2 ;; esac
    d="${XDG_DATA_HOME:-$HOME/.local/share}/over9k"; mkdir -p "$d"
    { grep -v "^$k " "$d/todo-defaults" 2>/dev/null; echo "$k $v"; } > "$d/todo-defaults.tmp" && mv "$d/todo-defaults.tmp" "$d/todo-defaults" ;;
  check)
    command -v git >/dev/null 2>&1 || echo "git: the sidebar's branch, changes and push/pull"
    command -v jq >/dev/null 2>&1 || echo "jq: subagents, background tasks, resume, hand-off, the to-do hook"
    { command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; } || echo "python 3: the Timeline, TODO.md sync"
    exit 0 ;;
  *) sed -n '2,12s/^# \{0,1\}//p' "$0"; exit 2 ;;
esac
