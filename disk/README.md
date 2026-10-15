# Disk, temp files and the boot hang

## What happened (2026-10-15)

The Mac hung at the progress bar after the login password on every restart and was reinstalled
twice in one week. It was not broken. At boot, before login, macOS's `dirhelper` deletes everything
in `/private/tmp` and `$TMPDIR` (`/private/var/folders/*/*/T`), and `launchd` waits for it. Agents
had left millions of files there, so the boot waited for hours. The force-reset snapshot showed only
`kernel_task`, `launchd` and two `dirhelper`s running 33 minutes in. A reinstall "fixes" it only
because it ends with those folders empty.

Where the files came from: per-run copies of the game repos.
- wildshard's own git hooks copied the whole 5 GB, 23k-file tree with `git archive | tar -x` on every
  source commit (`precommit-inputs.mjs`) and every push (`local-gate.py`), about 4,150 commits a week.
- On top of that came about 2,000 hand-made agent exports and `serve-build --head` previews.
- rockhop's `store-build` and timelapse added about 220 more.
- One day's disk-writes report showed `tar` writing 8.5 TB.

## In an emergency

`~/recovery-tools/diagnose.sh` and `~/recovery-tools/fix-boot.sh` work from the Recovery Terminal
(`bash /Volumes/Data/Users/raynos/recovery-tools/diagnose.sh`). Waiting also works; it finishes.

## Routine

    audit-disk temp      # before a restart: boot-purge file count (keep well under 100,000)
    audit-disk           # who is using the SSD: repos, .git, ./tmp, mirror slots, agent state
    cleanup-temp         # stale /tmp + $TMPDIR entries (dry run; --yes deletes)
    cleanup-disk         # dead worktrees, idle mirror slots, orphaned previews (dry run; --yes)

## Rules for the game repos (in each repo's AGENTS.md)

- Never copy the repo: no `git archive | tar -x` exports, clones or worktrees per run.
- An exact-commit build or check runs in the repo's build mirror,
  `node scripts/build-mirror.mjs run <rev> [--slot name] -- <cmd>`. It's one persistent copy per slot
  under the git-ignored `./tmp/build-mirror`, synced file by file with `git read-tree -u` and a private
  index. A lock serializes users, and git inside the mirror cannot see the checkout
  (`GIT_CEILING_DIRECTORIES`).
- Scratch goes under `<repo>/tmp/<task>`, so `du -sh */tmp` names the culprit. Never `/tmp`,
  `$TMPDIR` or a session scratchpad for anything big. Delete it with `rm -rf <exact path>` when done.
  Never `mv` trees to `/tmp/delete-me-*`.

## Done

- rockhop `4ec6e7128`, `35bfe6124`: build mirror; `store-build` and timelapse moved onto it; scratch
  moved to `./tmp`; `node_modules` repaired (it pointed into a deleted `/tmp` export).
- wildshard `1e722a4f4`, `8306e195a` (pushed): build mirror. The pre-commit check (slot `commit`), push
  gate (slot `gate`, Vercel's tree), `serve-build --head/--rev` (slot `serve`, builds in `./tmp/serve`),
  green-prefix probes and prepare-to-exit all use it.
- Deleted about 22 GB: old rockhop clones, wildshard `.git/commit-export*`, a stale agent worktree,
  `.native-build`, `.wildshard/cache`, a 13 GB Codex worktree, and 13 dead worktree registrations.
- wildshard storage policy (`docs/process/STORAGE.md`, `scripts/repo-size.mjs`): 1 MB per blob, 10 MB
  of new binary per push, 100 MB a week (warning only) outside the runtime roots, migration mode (existing files
  grandfathered), enforced in pre-commit, pre-push and CI (`.github/workflows/storage.yml`).
- wildshard auto-push removed from post-commit; landing recipe and feature worktrees removed (`37c6bd193`).

## Decisions (2026-10-15)

- wildshard auto-push after every commit: **off for good.** Push with `scripts/push-main.sh`.
- Landing recipes and feature worktrees: **removed.** Agents work on `main` in the one checkout.
- The push gate builds Vercel's tree (no art/progress/sources): a 1 GB mirror slot, not 7 GB.
- wildshard keeps 4 mirror slots (build, commit, gate, serve; about 8 GB in total) so jobs never wait on each other.
  They share the repo's `.git`: only the checked-out files are copied, because tsc/vite need real files, and
  the shared checkout carries other agents' uncommitted work.
  They get cheaper once wildshard's repo is compacted, which is planned after the shard platform plan.
- wildshard weekly budget: 100 MB, a warning only, until the repo is compacted (`2eb68df24`). 1 MB per file,
  10 MB per push and the forbidden types stay hard.
- rockhop `.git` (38 GB; about 24 GB is 5 Codex turn-diff checkpoint refs) and the clean-history
  cutover (`~/projects/games/rockhop-replacement`): Jake handles these.
- wildshard `progress/` videos: kept until a history rewrite. The storage policy blocks new ones.
- house / house-blender (big `tmp/`, 9.8 GB `.git`): not audited yet.
