#!/usr/bin/env bash
# SessionStart hook: tell the model how to sign its commits.
#
# Claude Code's own `attribution.commit` is fixed text (no model placeholder),
# so it would stamp one model's name on every commit, whether the session runs
# Opus, Fable or Sonnet. settings.managed.json turns it off ("commit": "") and
# this one line asks the model to sign with its own exact ID instead, the form
# the repos' commit-msg hooks check (`Assisted-by: AGENT:MODEL`, no AI
# Co-Authored-By).
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Git commits you write end with one trailer `Assisted-by: Claude:<your exact model ID, as your system prompt names it, e.g. claude-opus-5-5 or claude-fable-5-2>`. Never add a Co-Authored-By line for an AI."}}
JSON
