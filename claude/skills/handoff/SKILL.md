---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

# Handoff

> Adapted from the [mattpocock handoff skill](https://github.com/mattpocock/skills/tree/main/skills/productivity/handoff) (via kami-kakushi). Frontmatter unchanged. Save location is the repo-local, git-ignored `tmp/` — not the OS temp dir, not a global scratchpad, not anywhere that gets committed.

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it to the repo-local, git-ignored `tmp/`.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, journals, status snapshots, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
