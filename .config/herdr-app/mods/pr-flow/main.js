// PR Flow: every PR your agents opened and where it is. A side panel with a list; a PR opens
// in the same panel. It only reads: nothing here writes to GitHub or sends to an agent.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, Scrollbar, TextView, v_virtual_list, TextareaState, Textarea } from "gpui-base";
import { agents, panes, spaces, focused, exec, run, theme, props, settings, shared, setShared, nextCommand, window as appWindow } from "herdr";
import { MERGE_METHODS, createGh, parseRemote, parseWorktrees, runIdFromUrl } from "./gh.js";
import { createTracker } from "./tracker.js";
import { translator, relative, effectiveLang } from "./i18n.js";
import { facts, steps, openThreads, logTail, flowLine, flowRows, jobSteps, issueState, issueLabel, orgsOf, byOrg, reposOf, byRepo } from "./present.js";
import { parseDiff, commentTarget, withComments } from "./diff.js";
import { parseDuration, sanitize } from "./text.js";
import { REPO, due, parseRelease, offer, updatePrompt } from "./update.js";
import { VERSION } from "./version.js";

const MOD = "pr-flow";
const VIEW_KEY = "pr-flow.view";
const LANG_KEY = "pr-flow.lang";
const TICK_MS = 5000;
const FILES_FOLD_AT = 10; // more changed files than this start folded

const icon = (name, size, color) => svg(`mods/${MOD}/${name}.svg`).size(size).flex_none().text_color(color);
const toneColor = (t, tone) => ({ ok: t.ansi2, bad: t.ansi1, warn: t.blocked, wait: t.foreground, run: t.working, merge: t.ansi2, merged: t.ansi5, dim: t.dim, comment: t.muted, todo: t.dim }[tone] ?? t.muted);
const mono = () => settings().font_family ?? "JetBrains Mono";

function factIcon(tone, t) {
  const c = toneColor(t, tone);
  if (tone === "ok") return icon("check", 12, c);
  if (tone === "bad") return icon("cross", 12, c);
  if (tone === "run") return icon("spinner", 11, c).spin(900);
  if (tone === "comment" || tone === "warn") return icon("comment", 12, c);
  if (tone === "merge" || tone === "merged") return icon("merge", 12, c);
  return icon("pending", 10, c);
}
const fact = (f, t) => h_flex().flex_none().gap(4).items_center().child(factIcon(f.tone, t))
  .child(div().text_size(12).text_color(f.tone === "ok" || f.tone === "comment" ? t.muted : toneColor(t, f.tone)).child(f.label));

function agentDot(status, t) {
  if (status === "working") return icon("spinner", 11, t.working).spin(900);
  const color = status === "blocked" ? t.blocked : status === "done" ? t.done : t.dim;
  return div().size(7).mx(2).flex_none().rounded(99).bg(color);
}

function stepMark(tone, t) {
  const c = toneColor(t, tone);
  const round = (el) => h_flex().size(20).flex_none().rounded(99).bg(c).items_center().justify_center().child(el);
  if (tone === "ok") return round(icon("check", 12, t.background));
  if (tone === "bad") return round(icon("cross", 12, t.background));
  if (tone === "warn") return round(icon("comment", 11, t.background));
  const box = h_flex().size(20).flex_none().items_center().justify_center();
  if (tone === "run") return box.child(icon("spinner", 15, c).spin(900));
  if (tone === "wait") return box.child(div().size(12).rounded(99).border_2().border_color(c));
  return box.child(div().size(9).rounded(99).border_1().border_color(t.dim));
}

function fileLine(path) {
  const parts = String(path).split("/"), name = parts.pop();
  return { dir: parts.length ? parts.join("/") + "/" : "", name };
}

function openExternal(url) {
  const platform = appWindow()?.platform;
  const [cmd, args] = platform === "macos" ? ["open", [url]] : platform === "windows" ? ["explorer.exe", [url]] : ["xdg-open", [url]];
  exec(cmd, args).catch(() => {});
}

// An app started from the Finder has no LANG, so ask macOS too.
const LOCALE = 'l="${LC_ALL:-${LC_MESSAGES:-$LANG}}"; case "$l" in ""|C|C.*|POSIX) l=$(defaults read -g AppleLocale 2>/dev/null);; esac; printf %s "$l"';
const systemLang = () => exec("sh", ["-c", LOCALE]).then((r) => (/^ko/i.test(r.stdout) ? "ko" : "en")).catch(() => "en");

function agentList() {
  const allPanes = panes(), allSpaces = spaces();
  return agents().map((a) => {
    const pane = allPanes.find((p) => p.terminal === a.address);
    return {
      address: a.address, status: a.status, app: a.program?.name ?? a.app ?? "Agent", name: a.space_name || a.tab_name || "",
      cwd: pane?.cwd ?? null, branch: pane?.branch ?? null, on: allSpaces.find((s) => s.id === a.space)?.machine ?? null,
    };
  });
}

export default class PrFlow extends View {
  init(_props, cx) {
    const p = props() ?? {};
    this.viewer = p.screen === "viewer";
    this.system = localStorage.getItem("lang") ?? "en";
    this.useLang();
    this.handle = cx.focus_handle();
    this.scroll = null;
    cx.spawn(async (cx) => {
      const system = await systemLang();
      if (system !== this.system) { this.system = system; localStorage.setItem("lang", system); cx.notify(); }
    });
    if (this.viewer) {
      this.loaded = null; this.file = 0;
      this.threads = []; this.head = null;
      this.composing = null; // { path, line, side }: the line being commented on
      this.sending = false; this.commentError = null;
      this.commentInput = TextareaState.new({ rows: 3, placeholder: this.t("comment_placeholder") });
      return;
    }

    this.gh = createGh(exec);
    this.tracker = createTracker({
      gh: this.gh,
      settings: {
        pollMs: Math.max(10_000, Number(p.poll_seconds) * 1000 || 30_000),
        ciWaitMs: parseDuration(p.ci_wait, 120_000),
        aiChecks: (Array.isArray(p.ai_checks) ? p.ai_checks : []).map((x) => String(x).toLowerCase()),
        mine: p.mine === true,
      },
      remoteOf: async (cwd, on) => {
        const r = await exec("git", ["--no-optional-locks", "remote", "get-url", "origin"], { cwd, on: on ?? undefined });
        return r.code === 0 ? parseRemote(r.stdout) : null;
      },
      worktreesOf: async (cwd, on) => {
        const r = await exec("git", ["--no-optional-locks", "worktree", "list", "--porcelain"], { cwd, on: on ?? undefined });
        return r.code === 0 ? parseWorktrees(r.stdout) : [];
      },
      store: {
        load: () => { try { return JSON.parse(localStorage.getItem("tracked") ?? "{}"); } catch { return {}; } },
        save: (data) => localStorage.setItem("tracked", JSON.stringify(data)),
      },
    });
    this.url = null; // the open PR; null shows the list
    this.selected = 0;
    this.org = localStorage.getItem("org") || null; // the owner the list shows; null: all
    this.repo = localStorage.getItem("repo") || null; // within it, one repo; null: all of the owner's
    this.logs = new Map(); // run id -> { name, runId, repo, tail, full, failed }
    this.opened = new Set(); // timeline rows showing their steps or checks
    this.filesFold = new Map(); // url -> whether the changed files are showing, once you chose
    this.issueUrl = null; // the issue open in the panel
    this.issueData = new Map(); // url -> issue, or { failed: true }
    this.ghReady = true;
    this.busy = false;
    // The merge button, only with the `merge` prop ("squash", "merge" or "rebase"). The first press
    // arms it for a few seconds, the second merges.
    this.mergeMethod = MERGE_METHODS.includes(p.merge) ? p.merge : null;
    this.mergeArmed = null; // url
    this.merging = null; // url
    this.mergeError = null; // { url, message }
    // Update notice: at most one check a day, kept in localStorage across restarts.
    this.update = this.loadUpdate();
    this.copied = false;
    this.checkUpdate(cx);
    cx.timer.every(60 * 60_000, (cx) => this.checkUpdate(cx));
    this.tick(cx);
    cx.timer.every(TICK_MS, (cx) => this.tick(cx));
    cx.timer.every(60_000, (cx) => cx.notify()); // "5분 전" moves on
    cx.spawn(async (cx) => {
      this.ghReady = await this.gh.authOk().catch(() => false);
      cx.notify();
    });
    // "pr-flow.next" and friends, for keys.json and the command line.
    cx.spawn(async (cx) => {
      for (;;) { const c = await nextCommand(); this.command(c, cx); cx.notify(); }
    });
  }

  command(name, cx) {
    const cards = this.shown(), card = this.url ? this.current() : cards[this.selected];
    // pr-flow.org:<owner> shows one owner's PRs; pr-flow.org alone shows all.
    // pr-flow.repo:<owner/name> shows one repo (and chooses its owner).
    if (String(name).startsWith("org")) this.setOrg(String(name).split(":")[1] || null);
    else if (String(name).startsWith("repo")) { const repo = String(name).split(":")[1] || null; if (repo) this.setOrg(repo.split("/")[0]); this.setRepo(repo); }
    else if (name === "next") this.select(Math.min(this.selected + 1, cards.length - 1));
    else if (name === "prev") this.select(this.selected - 1);
    else if (name === "open" && card) this.openPr(card.url, cx);
    else if (name === "back") this.back(cx);
    else if (name === "agent") this.goToAgent(card);
    else if (name === "github" && card) openExternal(card.url);
    else if (name === "refresh") this.refreshNow(cx);
    else if (name === "settings") this.settingsOpen = !this.settingsOpen;
    else if (name.startsWith("lang-")) setShared(LANG_KEY, name.slice(5));
    else if (name === "first-run" && card?.flow) { const r = flowRows(card, this.t, Date.now())[0]; if (r) this.toggleRun(card, r.id, cx); }
    else if (name === "last-run" && card?.flow) { const r = flowRows(card, this.t, Date.now()).at(-1); if (r) this.toggleRun(card, r.id, cx); }
    else if (name === "run-log" && card?.flow) { const r = flowRows(card, this.t, Date.now()).find((x) => x.failed); if (r) this.openViewer({ kind: "log", repo: card.repo, runId: String(r.id), name: r.label, url: r.url, title: card.pr.title, number: card.number }); }
    else if (name === "first-issue" && card?.issues?.[0]) this.openIssue(card.issues[0].url, cx);
    else if (name === "issue-back") this.issueUrl = null;
    else if (name === "checks") this.toggle("checks");
    else if (name === "first-file" && card?.pr?.files?.[0]) this.showFile(card, card.pr.files[0].path);
    else if (name === "log" && card) { const l = this.logFor(card); if (l?.tail) this.showLog(card, l); }
  }

  loadUpdate() {
    try { const s = JSON.parse(localStorage.getItem("update") ?? "{}"); return s && typeof s === "object" ? s : {}; } catch { return {}; }
  }

  saveUpdate(change) {
    this.update = { ...this.update, ...change };
    localStorage.setItem("update", JSON.stringify(this.update));
  }

  checkUpdate(cx) {
    if (!due(this.update, Date.now())) return;
    this.saveUpdate({ checked: Date.now() }); // before asking, so a failure waits a day too
    cx.spawn(async (cx) => {
      try { const latest = parseRelease(await this.gh.latestRelease(REPO)); if (latest) { this.saveUpdate({ latest }); cx.notify(); } } catch {}
    });
  }

  toggle(key) {
    if (this.opened.has(key)) this.opened.delete(key); else this.opened.add(key);
  }

  // Long lists start folded, so they don't push the description out of reach.
  filesOpen(card, count) {
    return this.filesFold.get(card.url) ?? count <= FILES_FOLD_AT;
  }

  toggleRun(card, runId, cx) {
    this.toggle(`run-${runId}`);
    if (!this.opened.has(`run-${runId}`)) return;
    cx.spawn(async (cx) => { await this.tracker.loadJobs(card.url, runId); cx.notify(); });
  }

  openIssue(url, cx) {
    this.issueUrl = url;
    this.handle.focus();
    cx.spawn(async (cx) => {
      try { this.issueData.set(url, await this.gh.fetchIssue(url)); }
      catch { if (!this.issueData.has(url)) this.issueData.set(url, { failed: true }); }
      cx.notify();
    });
  }

  showFile(card, path) {
    const { pr } = card;
    this.openViewer({ kind: "diff", url: card.url, path, title: pr.title, number: card.number, additions: pr.additions, deletions: pr.deletions });
  }

  showLog(card, log) {
    this.openViewer({ kind: "log", repo: log.repo, runId: log.runId, name: log.name, url: log.url, title: card.pr.title, number: card.number });
  }

  // Saved in shared state, so the viewer pane follows the panel. A layout's `lang` prop is the default.
  langChoice() {
    return shared(LANG_KEY) ?? props()?.lang ?? "auto";
  }

  useLang() {
    const lang = effectiveLang(this.langChoice(), this.system);
    if (lang !== this.lang) { this.lang = lang; this.t = translator(lang); }
  }

  signature() {
    return JSON.stringify(this.tracker.cards().map((c) => [c.url, c.pr?.updatedAt, c.pr?.state, c.status?.name, c.status?.review, c.status?.comments, c.status?.ci?.kind, c.status?.ci?.checks?.map((x) => x.state), c.agent?.address, c.agent?.status, c.issues?.map((i) => i.state), c.flow?.active, c.flow?.runs?.map((r) => [r.id, r.status, r.conclusion]), Object.values(c.flow?.jobs ?? {}).map((j) => j.jobs.map((x) => x.steps.map((y) => y.status)))])) + this.tracker.lastError();
  }

  tick(cx) {
    if (this.busy) return;
    this.busy = true;
    const before = this.signature();
    cx.spawn(async (cx) => {
      try { await this.tracker.tick(agentList()); } finally { this.busy = false; }
      if (this.signature() !== before) { this.syncLog(cx); cx.notify(); }
    });
  }

  refreshNow(cx) {
    this.refreshing = true;
    this.ghReady = true;
    cx.notify();
    cx.spawn(async (cx) => {
      await this.tracker.refreshAll();
      this.ghReady = await this.gh.authOk().catch(() => false);
      this.refreshing = false;
      this.syncLog(cx);
      cx.notify();
    });
  }

  current() {
    return this.url ? this.tracker.cards().find((c) => c.url === this.url) ?? null : null;
  }

  openPr(url, cx) {
    this.url = url;
    this.handle.focus();
    this.syncLog(cx);
    cx.notify();
  }

  back(cx) {
    this.url = null;
    this.issueUrl = null;
    this.handle.focus();
    cx.notify();
  }

  // Fetches the failed CI log for the open PR once per run.
  syncLog(cx) {
    const card = this.current();
    const failed = card?.status?.ci?.failed?.[0];
    const runId = runIdFromUrl(failed?.url);
    if (!runId || this.logs.has(runId)) return;
    const entry = { name: failed.name, runId, repo: card.repo, url: failed.url, tail: null, failed: false };
    this.logs.set(runId, entry);
    cx.spawn(async (cx) => {
      try { entry.tail = logTail(sanitize(await this.gh.failedLog(card.repo, runId))); }
      catch { entry.failed = true; }
      cx.notify();
    });
  }

  canMerge(card) {
    const pr = card.pr;
    return Boolean(this.mergeMethod && pr && pr.state === "OPEN" && !pr.isDraft && pr.mergeable === "MERGEABLE" && card.status?.name === "ready");
  }

  pressMerge(card, cx) {
    if (this.merging || !this.canMerge(card)) return;
    if (this.mergeArmed !== card.url) {
      this.mergeArmed = card.url;
      this.mergeError = null;
      cx.timer.after(4000, (cx) => { if (this.mergeArmed === card.url) { this.mergeArmed = null; cx.notify(); } });
      return;
    }
    this.mergeArmed = null;
    this.merging = card.url;
    const sha = card.pr.headRefOid;
    cx.spawn(async (cx) => {
      try {
        await this.gh.merge(card.url, this.mergeMethod, sha);
        await this.tracker.refresh(card.url);
      } catch (error) {
        this.mergeError = { url: card.url, message: sanitize(error.message) };
      }
      this.merging = null;
      cx.notify();
    });
  }

  mergeButton(card, t) {
    const tr = this.t, armed = this.mergeArmed === card.url, busy = this.merging === card.url;
    const label = busy ? tr("merging") : armed ? tr("merge_confirm") : tr("merge_do", this.mergeMethod);
    return v_flex().px(14).pt(12).gap(6)
      .child(h_flex().id("merge").w_full().h(32).gap(6).items_center().justify_center().rounded(8)
        .bg(armed ? t.ansi2 : t.raised).text_color(armed ? t.background : t.foreground)
        .when(!busy, (e) => e.cursor_pointer().hover((s) => s.opacity(0.88)))
        .on_click((_e, cx) => { this.pressMerge(card, cx); cx.notify(); })
        .child(busy ? icon("spinner", 12, t.working).spin(900) : icon("merge", 13, armed ? t.background : t.ansi2))
        .child(div().text_size(12.5).font_medium().child(label)))
      .when(this.mergeError?.url === card.url, (e) => e.child(div().text_size(11.5).text_color(t.ansi1).child(this.mergeError.message)));
  }

  logFor(card) {
    const failed = card.status?.ci?.failed?.[0];
    if (!failed) return null;
    const runId = runIdFromUrl(failed.url);
    return runId ? this.logs.get(runId) ?? null : { name: failed.name, url: failed.url, external: true };
  }

  goToAgent(card) {
    if (card?.agent) run("agent.focus", { terminal: card.agent.address });
  }

  // One viewer pane at a time: a second file replaces what it shows.
  openViewer(target) {
    setShared(VIEW_KEY, { ...target, at: Date.now() });
    const all = panes();
    const open = all.find((p) => p.mod === MOD);
    if (open) { run("pane.focus", { pane: open.pane }); return; }
    const f = focused();
    const beside = all.find((p) => p.pane === f?.pane) ?? all.find((p) => p.tab === f?.tab && p.terminal);
    if (beside) run("pane.split", { direction: "right", pane: beside.pane, mod: MOD, props: { screen: "viewer" } });
    else run("tab.new", { name: "PR", mod: MOD, props: { screen: "viewer" } });
  }

  onKey(e, cx) {
    const cards = this.shown();
    if (this.settingsOpen) {
      if (e.key !== "escape" && e.key !== "backspace") return;
      this.settingsOpen = false;
    } else if (this.issueUrl) {
      if (e.key === "o") openExternal(this.issueUrl);
      else if (e.key === "escape" || e.key === "backspace") this.issueUrl = null;
      else return;
    } else if (this.url) {
      const card = this.current();
      if (e.key === "escape" || e.key === "backspace") this.back(cx);
      else if (e.key === "enter" || e.key === "g") this.goToAgent(card);
      else if (e.key === "o" && card) openExternal(card.url);
      else return;
    } else {
      if (e.key === "j" || e.key === "down") this.select(Math.min(this.selected + 1, cards.length - 1));
      else if (e.key === "k" || e.key === "up") this.select(Math.max(this.selected - 1, 0));
      else if (e.key === "enter" && cards[this.selected]) { this.openPr(cards[this.selected].url, cx); return; }
      else if (e.key === "g") this.goToAgent(cards[this.selected]);
      else if (e.key === "o" && cards[this.selected]) openExternal(cards[this.selected].url);
      else if (e.key === "r") { this.refreshNow(cx); return; }
      else return;
    }
    cx.stop_propagation();
    cx.notify();
  }

  select(index) {
    this.selected = Math.max(0, index);
    this.selectedUrl = this.shown()[this.selected]?.url;
  }

  // The list's cards: one owner's when one is chosen and still has PRs, else all; then one repo's
  // of those the same way.
  shown() {
    const owned = byOrg(this.tracker.cards(), this.org);
    return this.org ? byRepo(owned, this.repo) : owned;
  }

  setOrg(org) {
    if (org !== this.org) this.setRepo(null);
    this.org = org;
    localStorage.setItem("org", org ?? "");
    this.selected = 0;
    this.selectedUrl = null;
  }

  setRepo(repo) {
    this.repo = repo;
    localStorage.setItem("repo", repo ?? "");
    this.selected = 0;
    this.selectedUrl = null;
  }

  chip(id, label, count, active, onPick, t) {
    return h_flex().id(id).h(22).flex_none().px(8).gap(5).items_center().rounded(6).cursor_pointer()
      .bg(active ? t.selected : t.raised).text_color(active ? t.foreground : t.muted).hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { onPick(); cx.notify(); })
      .child(div().text_size(11.5).max_w(140).truncate().child(label))
      .child(div().text_size(11).text_color(t.dim).child(String(count)));
  }

  // One chip per owner under the header, when the list has more than one.
  orgBar(all, t) {
    const orgs = orgsOf(all);
    if (orgs.length < 2) return null;
    const on = orgs.some(([o]) => o === this.org) ? this.org : null;
    return h_flex().id("orgs").h(36).flex_none().px(10).gap(4).items_center().border_b(1).border_color(t.border).overflow_x_scrollbar()
      .child(this.chip("org-all", this.t("org_all"), all.length, on === null, () => this.setOrg(null), t))
      .children(orgs.map(([org, count]) => this.chip(`org-${org}`, org, count, on === org, () => this.setOrg(org), t)));
  }

  // Under a chosen owner, one chip per repo of theirs, when they have more than one.
  repoBar(all, t) {
    if (!this.org) return null;
    const owned = all.filter((c) => String(c.repo).split("/")[0] === this.org);
    const repos = reposOf(owned);
    if (repos.length < 2) return null;
    const on = repos.some(([r]) => r === this.repo) ? this.repo : null;
    return h_flex().id("repos").h(32).flex_none().px(10).gap(4).items_center().border_b(1).border_color(t.border).overflow_x_scrollbar()
      .child(this.chip("repo-all", this.t("repo_all"), owned.length, on === null, () => this.setRepo(null), t))
      .children(repos.map(([repo, count]) => this.chip(`repo-${repo}`, repo.split("/")[1], count, on === repo, () => this.setRepo(repo), t)));
  }

  header(count, t) {
    const tr = this.t;
    return h_flex().h(42).flex_none().px(14).gap(8).items_center().border_b(1).border_color(t.border)
      .child(div().font_semibold().child(tr("title")))
      .when(count > 0, (e) => e.child(div().px(6).rounded(5).bg(t.raised).text_size(11).text_color(t.muted).child(String(count))))
      .child(div().flex_1())
      .when(Boolean(offer(this.update, VERSION)), (e) => e.child(h_flex().id("update").h(22).px(7).gap(5).flex_none().items_center().rounded(6).text_size(11.5).cursor_pointer()
        .text_color(t.accent).hover((s) => s.bg(t.hover)).on_click((_e, cx) => { this.settingsOpen = true; cx.notify(); })
        .child(div().size(6).rounded(3).bg(t.accent)).child(tr("update_pill", offer(this.update, VERSION).tag))))
      .child(h_flex().id("settings").size(26).items_center().justify_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => { this.settingsOpen = true; cx.notify(); })
        .child(icon("settings", 14, t.muted)))
      .child(h_flex().id("refresh").size(26).items_center().justify_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => this.refreshNow(cx))
        .child(this.refreshing ? icon("spinner", 13, t.muted).spin(900) : icon("refresh", 14, t.muted)));
  }

  row(card, index, t) {
    const tr = this.t, now = Date.now();
    const done = card.pr?.state === "MERGED" && !card.flow?.active;
    const selected = index === this.selected;
    const short = card.repo.split("/")[1];
    const body = v_flex().id(`pr-${index}`).w_full().flex_none().px(10).py(10).gap(5).rounded(8).cursor_pointer().when(selected, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { this.selected = index; this.selectedUrl = card.url; this.openPr(card.url, cx); });
    if (!card.pr) {
      return body
        .child(div().w_full().truncate().text_color(t.muted).child(`${short} #${card.number}`))
        .child(div().w_full().truncate().text_size(12).text_color(card.error ? t.ansi1 : t.dim).child(card.error ? sanitize(card.error) : tr("loading")));
    }
    return body
      .child(div().w_full().truncate().font_medium().text_color(done ? t.muted : t.foreground).child(card.pr.title))
      .child(h_flex().w_full().gap(6).items_center().text_size(11.5).text_color(t.dim)
        .child(div().min_w(0).truncate().child(`${short} #${card.number}`))
        .child(div().flex_none().child("·"))
        .child(div().flex_none().child(issueLabel(card, tr)))
        .child(div().flex_1())
        .child(div().flex_none().child(relative(now - Date.parse(card.pr.updatedAt), tr))))
      .child(h_flex().w_full().gap(10).items_center().overflow_hidden().children(facts(card, tr).map((f) => fact(f, t))))
      .when(Boolean(flowLine(card, tr)), (e) => { const line = flowLine(card, tr); return e.child(h_flex().w_full().gap(5).items_center()
        .child(factIcon(line.tone, t))
        .child(div().flex_1().min_w(0).truncate().text_size(12).text_color(line.tone === "ok" ? t.muted : toneColor(t, line.tone)).child(sanitize(line.label)))
        .when(Boolean(line.more), (x) => x.child(div().flex_none().text_size(11.5).text_color(t.dim).child(line.more)))); })
      .when(Boolean(card.agent), (e) => e.child(h_flex().w_full().gap(6).items_center().pt(1)
        .child(agentDot(card.agent.status, t))
        .child(div().min_w(0).truncate().text_size(11.5).text_color(t.muted).child(`${card.agent.app} · ${card.agent.name}`))));
  }

  list(t) {
    const tr = this.t, all = this.tracker.cards(), cards = this.shown();
    if (!cards.length) {
      const noGh = !this.ghReady;
      return v_flex().size_full().child(this.header(0, t))
        .child(v_flex().flex_1().items_center().justify_center().gap(6).px(24)
          .child(icon("merge", 22, t.dim))
          .child(div().pt(4).font_medium().child(tr(noGh ? "gh_title" : "empty_title")))
          .child(div().text_center().text_size(12).text_color(t.dim).child(tr(noGh ? "gh_body" : "empty_body"))));
    }
    // The selection stays on its PR when a new one pushes the rows down.
    const kept = cards.findIndex((c) => c.url === this.selectedUrl);
    this.selected = kept >= 0 ? kept : Math.min(this.selected, cards.length - 1);
    this.selectedUrl = cards[this.selected].url;
    const error = this.tracker.lastError();
    const bar = this.orgBar(all, t), repoBar = bar && this.repoBar(all, t);
    return v_flex().size_full().child(this.header(cards.length, t))
      .when(Boolean(bar), (e) => e.child(bar))
      .when(Boolean(repoBar), (e) => e.child(repoBar))
      .child(v_flex().id("pr-list").flex_1().min_h(0).overflow_y_scrollbar().p(6).gap(2).children(cards.map((c, i) => this.row(c, i, t))))
      .when(Boolean(error), (e) => e.child(div().flex_none().px(14).py(6).border_t(1).border_color(t.border).truncate().text_size(11).text_color(t.ansi1).child(sanitize(error))));
  }

  settingsScreen(t) {
    const tr = this.t, choice = this.langChoice();
    const options = [["auto", tr("lang_auto")], ["ko", "한국어"], ["en", "English"]];
    const latest = offer(this.update, VERSION), checking = !this.update.off;
    const button = (id, label, primary, action) => h_flex().id(id).h(28).px(10).flex_none().items_center().rounded(7).border_1()
      .border_color(primary ? t.solid : t.input).bg(primary ? t.solid : t.raised).text_color(primary ? t.solid_foreground : t.foreground)
      .text_size(12).cursor_pointer().hover((st) => st.opacity(0.88)).on_click(action).child(label);
    const update = latest && v_flex().px(14).gap(8)
      .child(div().text_size(13.5).font_semibold().child(tr("update_title", latest.tag)))
      .child(div().text_size(12).text_color(t.muted).child(tr("update_have", VERSION)))
      .child(div().px(10).py(8).rounded(8).bg(t.raised).border_1().border_color(t.border).font_family(mono()).text_size(11.5).child(updatePrompt(this.lang)))
      .child(h_flex().gap(6).flex_wrap()
        .child(button("update-copy", this.copied ? tr("update_copied") : tr("update_copy"), true, (_e, cx) => { cx.write_to_clipboard(updatePrompt(this.lang)); this.copied = true; cx.notify(); }))
        .child(button("update-page", tr("update_page"), false, () => openExternal(latest.url)))
        .child(button("update-later", tr("update_later"), false, (_e, cx) => { this.saveUpdate({ dismissed: latest.tag }); cx.notify(); })))
      .child(div().pt(6).text_size(11.5).text_color(t.dim).child(tr("update_changed")))
      .child(div().h(220).flex_none().text_size(12).text_color(t.muted)
        .child(TextView.markdown("update-notes", latest.notes?.trim() || tr("update_no_notes")).scrollable(true).selectable(true).size_full()));
    return v_flex().size_full()
      .child(h_flex().h(42).flex_none().px(8).gap(4).items_center().border_b(1).border_color(t.border)
        .child(h_flex().id("settings-back").px(6).h(26).gap(2).items_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover))
          .on_click((_e, cx) => { this.settingsOpen = false; cx.notify(); })
          .child(icon("back", 14, t.muted)).child(div().text_color(t.muted).child(tr("back"))))
        .child(div().flex_1())
        .child(div().pr(6).font_semibold().child(tr("settings"))))
      .child(this.section(tr("language"), t))
      .child(v_flex().px(8).gap(1).children(options.map(([value, label]) =>
        h_flex().id(`lang-${value}`).w_full().h(32).flex_none().px(6).gap(8).items_center().rounded(6).cursor_pointer().when(choice === value, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover))
          .on_click(() => setShared(LANG_KEY, value))
          .child(div().flex_1().child(label))
          .when(choice === value, (e) => e.child(icon("check", 13, t.ansi2))))))
      .child(this.section(tr("version"), t))
      .child(update || div().px(14).text_size(12.5).text_color(t.muted).child(checking ? tr("update_latest", VERSION) : tr("update_off", VERSION)))
      .child(div().px(8).pt(8).child(h_flex().id("update-check").w_full().h(32).px(6).gap(8).items_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => { this.saveUpdate({ off: checking, checked: 0 }); this.checkUpdate(cx); cx.notify(); })
        .child(div().flex_1().child(tr("update_check")))
        .when(checking, (e) => e.child(icon("check", 13, t.ansi2)))));
  }

  section(title, t) {
    return div().px(14).pt(16).pb(8).text_size(11.5).font_medium().text_color(t.dim).child(title);
  }

  logBlock(card, t) {
    const tr = this.t, log = this.logFor(card);
    if (!log) return null;
    const box = v_flex().id("log").w_full().p(10).rounded(8).bg(t.background).border_1().border_color(t.border).font_family(mono()).text_size(11).text_color(t.muted).cursor_pointer().hover((s) => s.border_color(t.input));
    if (log.external || log.failed) {
      return div().px(14).child(box.on_click(() => openExternal(log.url)).child(div().font_family(settings().ui_font_family ?? mono()).child(log.external ? tr("open_github") : tr("log_failed"))));
    }
    if (!log.tail) return div().px(14).child(box.child(div().child(tr("loading"))));
    return div().px(14).child(box
      .on_click(() => this.showLog(card, log))
      .children(log.tail.map((l) => div().w_full().truncate().child(l || " "))));
  }

  detail(card, t) {
    const tr = this.t, now = Date.now();
    const top = h_flex().h(42).flex_none().px(8).gap(4).items_center().border_b(1).border_color(t.border)
      .child(h_flex().id("back").px(6).h(26).gap(2).items_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover)).on_click((_e, cx) => this.back(cx))
        .child(icon("back", 14, t.muted)).child(div().text_color(t.muted).child(tr("back"))))
      .child(div().flex_1())
      .child(h_flex().id("gh").px(8).h(26).gap(5).items_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover)).on_click(() => openExternal(card.url))
        .child(div().text_size(12).text_color(t.muted).child("GitHub")).child(icon("external", 12, t.muted)));
    if (!card.pr) {
      return v_flex().size_full().child(top).child(div().p(14).text_color(card.error ? t.ansi1 : t.dim).child(card.error ? sanitize(card.error) : tr("loading")));
    }
    const { pr, agent } = card;
    const all = [...steps(card, tr, now), ...flowRows(card, tr, now).map((r) => ({ ...r, run: true }))], threads = openThreads(card), files = pr.files ?? [], log = this.logBlock(card, t);
    const filesOpen = this.filesOpen(card, pr.changedFiles ?? files.length);
    const logName = this.logFor(card)?.name;
    return v_flex().size_full().child(top)
      .child(v_flex().id("detail").flex_1().min_h(0).overflow_y_scrollbar()
        .child(v_flex().px(14).pt(14).gap(6)
          .child(div().text_size(15).font_semibold().child(pr.title))
          .child(div().text_size(11.5).text_color(t.dim).child(`${card.repo} #${card.number}`))
          .child(h_flex().gap(5).items_center().text_size(11.5).text_color(t.muted).child(icon("branch", 12, t.dim)).child(div().min_w(0).truncate().child(`${pr.headRefName} → ${pr.baseRefName}`))))
        .when(this.canMerge(card) || this.merging === card.url || this.mergeError?.url === card.url, (e) => e.child(this.mergeButton(card, t)))
        .when(Boolean(agent), (e) => e.child(div().px(14).pt(12).child(
          h_flex().id("agent").w_full().px(10).h(38).gap(8).items_center().rounded(8).bg(t.raised).cursor_pointer().hover((s) => s.bg(t.hover)).on_click(() => this.goToAgent(card))
            .child(agentDot(agent.status, t))
            .child(v_flex().flex_1().min_w(0)
              .child(div().truncate().text_size(12.5).child(agent.name))
              .child(div().truncate().text_size(11).text_color(t.dim).child(`${agent.app} · ${tr(`a_${agent.status}`)}`)))
            .child(div().flex_none().text_size(11.5).text_color(t.muted).child(tr("agent_go"))).child(icon("arrow", 12, t.muted)))))
        .child(this.section(tr("progress"), t))
        .child(v_flex().px(14).children(all.map((row, i) => this.timelineRow(card, row, i === all.length - 1, t))))
        .when(Boolean(log), (e) => e.child(this.section(tr("failed_log", logName), t)).child(log))
        .when(!(card.issues ?? []).length, (e) => e.child(this.section(tr("issues_none"), t)))
        .when((card.issues ?? []).length > 0, (e) => e.child(this.section(tr("issues", card.issues.length), t)).child(v_flex().px(8).children(card.issues.map((issue, i) => {
          const state = issueState(issue, tr);
          return h_flex().id(`issue-${i}`).w_full().h(30).flex_none().px(6).gap(7).items_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover)).on_click((_e, cx) => this.openIssue(issue.url, cx))
            .child(div().size(8).flex_none().rounded(99).bg(toneColor(t, state.tone)))
            .child(div().flex_none().text_size(12).text_color(t.dim).child(`#${issue.number}`))
            .child(div().flex_1().min_w(0).truncate().child(issue.title))
            .child(div().flex_none().text_size(11.5).text_color(t.muted).child(state.label));
        }))))
        .when(threads.length > 0, (e) => e.child(this.section(tr("comments_open", threads.length), t)).child(v_flex().px(14).gap(8).children(threads.map((x) =>
          v_flex().w_full().p(10).gap(4).rounded(8).bg(t.raised)
            .child(h_flex().w_full().gap(6).text_size(11).text_color(t.dim).child(div().min_w(0).truncate().child(sanitize(x.where))).child(div().flex_1()).child(div().flex_none().child(sanitize(x.who))))
            .child(div().text_size(12.5).child(sanitize(x.body).slice(0, 400)))))))
        .child(h_flex().id("files-head").px(14).pt(16).pb(8).gap(6).items_center().text_size(11.5).font_medium().text_color(t.dim).cursor_pointer()
          .on_click((_e, cx) => { this.filesFold.set(card.url, !filesOpen); cx.notify(); })
          .child(div().child(tr("files", pr.changedFiles ?? files.length))).child(icon(filesOpen ? "down" : "arrow", 11, t.dim)).child(div().flex_1())
          .child(div().text_color(t.ansi2).child(`+${pr.additions ?? 0}`)).child(div().text_color(t.ansi1).child(`−${pr.deletions ?? 0}`)))
        .when(filesOpen, (e) => e.child(v_flex().px(8).children(files.map((f, i) => {
          const { dir, name } = fileLine(f.path);
          return h_flex().id(`f-${i}`).w_full().h(28).flex_none().px(6).gap(6).items_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover))
            .on_click(() => this.showFile(card, f.path))
            .child(h_flex().flex_1().min_w(0).child(div().min_w(0).truncate().text_color(t.dim).child(dir)).child(div().flex_none().max_w(220).truncate().child(name)))
            .child(div().flex_none().text_size(11).text_color(t.ansi2).child(`+${f.additions}`)).child(div().flex_none().text_size(11).text_color(t.ansi1).child(`−${f.deletions}`));
        }))))
        .when(Boolean(pr.body?.trim()), (e) => e.child(this.section(tr("description"), t)).child(div().px(14).pb(16).text_size(12.5).child(TextView.markdown(`body-${card.number}`, pr.body))))
        .child(div().h(14).flex_none()));
  }

  miniIcon(tone, t) {
    const c = toneColor(t, tone);
    if (tone === "ok") return icon("check", 11, c);
    if (tone === "bad") return icon("cross", 11, c);
    if (tone === "run") return icon("spinner", 10, c).spin(900);
    return icon("pending", 9, tone === "wait" ? t.foreground : t.dim);
  }

  // A workflow's steps, or the PR's checks, under their timeline row.
  subRows(card, row, t) {
    if (row.checks) {
      if (!this.opened.has("checks")) return null;
      const checks = [...card.status.ci.checks, ...card.status.ci.ai];
      return v_flex().w_full().pt(5).gap(3).children(checks.map((c) => h_flex().w_full().gap(6).items_center()
        .child(this.miniIcon(c.state === "passed" ? "ok" : c.state === "failed" ? "bad" : "run", t))
        .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(t.muted).child(sanitize(c.name)))));
    }
    if (!row.run || !this.opened.has(`run-${row.id}`)) return null;
    const jobs = jobSteps(card.flow.jobs?.[row.id]?.jobs);
    if (!jobs.length) return div().pt(5).text_size(11.5).text_color(t.dim).child(this.t("loading"));
    return v_flex().w_full().pt(5).gap(3).children(jobs.flatMap((job) => [
      ...(jobs.length > 1 ? [h_flex().w_full().pt(2).gap(6).items_center().child(this.miniIcon(job.tone, t)).child(div().min_w(0).truncate().text_size(11.5).font_medium().child(sanitize(job.name)))] : []),
      ...job.steps.map((x) => h_flex().w_full().gap(6).items_center().when(jobs.length > 1, (e) => e.pl(10))
        .child(this.miniIcon(x.tone, t))
        .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(x.tone === "todo" ? t.dim : t.muted).child(sanitize(x.name)))),
    ]));
  }

  timelineRow(card, row, last, t) {
    const tr = this.t, sub = this.subRows(card, row, t);
    const key = row.run ? `run-${row.id}` : "checks", openable = row.run || row.checks;
    const toggle = (_e, cx) => { if (row.run) this.toggleRun(card, row.id, cx); else this.toggle(key); cx.notify(); };
    const link = (id, label, onClick) => div().id(id).text_size(11.5).text_color(t.muted).cursor_pointer().hover((s) => s.text_color(t.foreground)).on_click(onClick).child(label);
    return h_flex().w_full().gap(10).items_start()
      .child(v_flex().w(20).flex_none().items_center().h_full().child(stepMark(row.tone, t)).when(!last, (e) => e.child(div().w(1).flex_1().min_h(14).bg(t.border))))
      .child(v_flex().flex_1().min_w(0).pb(last ? 0 : 12).gap(1)
        .child(h_flex().id(`row-${row.run ? row.id : row.label}`).w_full().gap(4).items_center().when(openable, (e) => e.cursor_pointer().on_click(toggle))
          .child(div().min_w(0).truncate().pt(1).font_medium().text_color(row.tone === "todo" ? t.dim : t.foreground).child(sanitize(row.label)))
          .when(openable, (e) => e.child(icon(this.opened.has(key) ? "down" : "arrow", 11, t.dim))))
        .when(Boolean(row.note), (e) => e.child(div().w_full().truncate().text_size(11.5).text_color(t.dim).child(sanitize(row.note))))
        .when(row.run, (e) => e.child(h_flex().pt(2).gap(10)
          .when(row.failed, (x) => x.child(link(`log-${row.id}`, tr("run_log"), () => this.openViewer({ kind: "log", repo: card.repo, runId: String(row.id), name: row.label, url: row.url, title: card.pr.title, number: card.number }))))
          .child(link(`web-${row.id}`, "GitHub", () => openExternal(row.url)))))
        .when(Boolean(sub), (e) => e.child(sub)));
  }

  issueScreen(url, t) {
    const tr = this.t, card = this.current(), issue = this.issueData.get(url);
    const top = h_flex().h(42).flex_none().px(8).gap(4).items_center().border_b(1).border_color(t.border)
      .child(h_flex().id("issue-back").px(6).h(26).gap(2).items_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover)).on_click((_e, cx) => { this.issueUrl = null; cx.notify(); })
        .child(icon("back", 14, t.muted)).child(div().text_color(t.muted).child(`PR #${card?.number ?? ""}`)))
      .child(div().flex_1())
      .child(h_flex().id("issue-gh").px(8).h(26).gap(5).items_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover)).on_click(() => openExternal(url))
        .child(div().text_size(12).text_color(t.muted).child("GitHub")).child(icon("external", 12, t.muted)));
    if (!issue || issue.failed) return v_flex().size_full().child(top).child(div().p(14).text_color(issue ? t.ansi1 : t.dim).child(issue ? tr("issue_failed") : tr("loading")));
    const state = issueState(issue, tr), comments = issue.comments ?? [], now = Date.now();
    return v_flex().size_full().child(top)
      .child(v_flex().id("issue").flex_1().min_h(0).overflow_y_scrollbar()
        .child(v_flex().px(14).pt(14).gap(6)
          .child(div().text_size(15).font_semibold().child(sanitize(issue.title)))
          .child(h_flex().gap(6).items_center().text_size(11.5).text_color(t.dim)
            .child(div().size(8).flex_none().rounded(99).bg(toneColor(t, state.tone)))
            .child(div().text_color(t.muted).child(state.label))
            .child(div().min_w(0).truncate().child(`#${issue.number} · ${sanitize(issue.author?.login ?? "")} · ${relative(now - Date.parse(issue.createdAt), tr)}`)))
          .when((issue.labels ?? []).length > 0, (e) => e.child(h_flex().flex_wrap().gap(4).pt(2).children(issue.labels.map((l) => div().px(6).rounded(5).bg(t.raised).text_size(11).text_color(t.muted).child(sanitize(l.name)))))))
        .when(Boolean(issue.body?.trim()), (e) => e.child(div().px(14).pt(14).text_size(12.5).child(TextView.markdown(`issue-${issue.number}`, sanitize(issue.body)))))
        .when(comments.length > 0, (e) => e.child(this.section(tr("issue_comments", comments.length), t)).child(v_flex().px(14).gap(8).children(comments.slice(-20).map((c, i) =>
          v_flex().w_full().p(10).gap(4).rounded(8).bg(t.raised)
            .child(h_flex().w_full().gap(6).text_size(11).text_color(t.dim).child(div().min_w(0).truncate().child(sanitize(c.author?.login ?? ""))).child(div().flex_1()).child(div().flex_none().child(relative(now - Date.parse(c.createdAt), tr))))
            .child(div().text_size(12.5).child(TextView.markdown(`issue-${issue.number}-c${i}`, sanitize(c.body))))))))
        .child(div().h(16).flex_none()));
  }

  // The viewer pane: a PR's diff or a CI log, wide enough to read.
  loadViewer(target, cx) {
    this.loaded = target.at;
    this.target = target;
    this.files = null; this.lines = null; this.viewError = false; this.file = 0;
    this.threads = []; this.cancelComment();
    const gh = createGh(exec);
    cx.spawn(async (cx) => {
      try {
        if (target.kind === "log") this.lines = sanitize(await gh.failedLog(target.repo, target.runId)).split("\n");
        else {
          this.gh = gh;
          const [diff, head] = await Promise.all([gh.fetchDiff(target.url), gh.fetchHead(target.url)]);
          this.head = head;
          this.files = parseDiff(diff).map((f) => ({ ...f, lines: f.lines.map((l) => ({ ...l, text: sanitize(l.text) })) }));
          this.file = Math.max(0, this.files.findIndex((f) => f.path === target.path));
          await this.loadThreads(target, cx);
        }
      } catch { this.viewError = true; }
      if (this.target === target) cx.notify();
    });
  }

  // Comments are extra: the diff still shows when they can't load.
  async loadThreads(target, cx) {
    try {
      const { threads } = await this.gh.fetchThreads(target.url);
      if (this.target !== target) return;
      this.threads = threads.map((x) => ({ ...x, comments: { nodes: (x.comments?.nodes ?? []).map((c) => ({ author: { login: sanitize(c.author?.login ?? "") }, body: sanitize(c.body) })) } }));
      cx.notify();
    } catch {}
  }

  startComment(row, cx) {
    const at = commentTarget(row);
    if (!at || this.sending) return;
    this.composing = { path: this.files[this.file].path, ...at };
    this.commentError = null;
    this.commentInput.focus();
    cx.notify();
  }

  cancelComment() {
    if (this.sending) return;
    this.composing = null;
    this.commentError = null;
    this.commentInput?.set_value("");
  }

  sendComment(cx) {
    const body = this.commentInput.value().trim(), at = this.composing, target = this.target;
    if (!body || !at || this.sending) return;
    this.sending = true;
    this.commentError = null;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        await this.gh.comment(target.url, { commitId: this.head, body, ...at });
        this.sending = false;
        this.cancelComment();
        await this.loadThreads(target, cx);
      } catch (error) {
        this.sending = false;
        this.commentError = sanitize(error.message);
      }
      cx.notify();
    });
  }

  composer(t) {
    const tr = this.t, at = this.composing;
    const button = (id, label, primary, action) => h_flex().id(id).h(28).px(12).flex_none().items_center().rounded(6).text_size(12).cursor_pointer()
      .bg(primary ? t.solid : t.raised).text_color(primary ? t.solid_foreground : t.foreground).hover((s) => s.opacity(0.88)).on_click(action).child(label);
    return v_flex().id("composer").w_full().flex_none().p(10).gap(8).border_t(1).border_color(t.border).text_size(12.5)
      .on_key_down((e, cx) => {
        if (e.key === "escape") { this.cancelComment(); cx.notify(); cx.stop_propagation(); }
        else if (e.key === "enter" && e.modifiers?.platform) { this.sendComment(cx); cx.stop_propagation(); }
      })
      .child(div().truncate().text_size(11.5).text_color(t.dim).child(tr("comment_on", `${at.path}:${at.line}`)))
      .child(Textarea.new(this.commentInput).w_full().px(8).py(6).rounded(6).border_1().border_color(t.accent).bg(t.raised).text_color(t.foreground))
      .when(Boolean(this.commentError), (e) => e.child(div().text_size(11.5).text_color(t.ansi1).child(this.commentError)))
      .child(h_flex().w_full().gap(6).items_center().child(div().flex_1().text_size(11).text_color(t.dim).child("⌘↵"))
        .child(button("comment-cancel", tr("comment_cancel"), false, (_e, cx) => { this.cancelComment(); cx.notify(); }))
        .child(button("comment-send", tr(this.sending ? "comment_sending" : "comment_send"), true, (_e, cx) => this.sendComment(cx))));
  }

  closeViewer() {
    const mine = panes().find((p) => p.mod === MOD);
    if (mine) run("pane.close", { pane: mine.pane });
  }

  viewerRow(l, t) {
    if (l.kind === "comment-head" || l.kind === "comment") {
      return h_flex().w_full().h(20).flex_none().pl(98).items_center().bg(t.raised)
        .text_color(l.kind === "comment" ? t.foreground : t.dim).child(div().whitespace_nowrap().child(l.text || " "));
    }
    if (l.kind === "hunk" || l.kind === "meta") return h_flex().w_full().h(20).flex_none().px(12).items_center().bg(t.raised).text_color(t.dim).child(div().truncate().child(l.text || "⋯"));
    const add = l.kind === "add", del = l.kind === "del";
    const at = commentTarget(l), mine = this.composing;
    const chosen = mine && at && mine.path === this.files[this.file]?.path && mine.line === at.line && mine.side === at.side;
    return h_flex().w_full().h(20).flex_none().items_center().cursor_pointer().when(chosen, (e) => e.bg(t.selected)).when(!chosen && add, (e) => e.bg(t.ansi2 + "18")).when(!chosen && del, (e) => e.bg(t.ansi1 + "18"))
      .child(div().w(38).flex_none().text_right().text_color(t.dim).child(l.oldNo === undefined ? "" : String(l.oldNo)))
      .child(div().w(38).flex_none().text_right().text_color(t.dim).child(l.newNo === undefined ? "" : String(l.newNo)))
      .child(div().w(22).flex_none().text_center().text_color(add ? t.ansi2 : del ? t.ansi1 : t.dim).child(add ? "+" : del ? "-" : ""))
      .child(div().flex_1().whitespace_nowrap().child(l.text));
  }

  viewerBody(t) {
    const tr = this.t, target = this.target;
    if (this.viewError) {
      return v_flex().flex_1().items_center().justify_center().gap(10).px(24)
        .child(div().text_center().text_color(t.muted).child(tr(target.kind === "log" ? "log_failed" : "diff_failed")))
        .child(div().id("gh").px(10).py(5).rounded(6).bg(t.raised).cursor_pointer().hover((s) => s.bg(t.hover)).on_click(() => openExternal(target.url)).child(tr("open_github")));
    }
    if (target.kind === "log") {
      if (!this.lines) return div().p(14).text_color(t.dim).child(tr("loading"));
      const lines = this.lines;
      return div().flex_1().min_h(0).relative().font_family(mono()).text_size(11.5).child(div().id("log-x").size_full().overflow_x_scrollbar().child(div().min_w(Math.max(600, ...lines.map((l) => l.length * 7 + 40))).h_full().child(
        v_virtual_list("log", lines.length, 20, (i) => String(i), (r) => lines.slice(r.start, r.end).map((l) => div().h(20).flex_none().px(12).whitespace_nowrap().text_color(t.muted).child(l || " "))).size_full())))
        .child(Scrollbar.vertical("log").viewport_from_layout().absolute().inset_0());
    }
    if (!this.files) return div().p(14).text_color(t.dim).child(tr("loading"));
    if (!this.files.length) return div().p(14).text_color(t.dim).child(tr("no_diff"));
    const narrow = (this.size?.width ?? 800) < 620;
    const path = this.files[this.file]?.path;
    const rows = withComments(this.files[this.file]?.lines ?? [], this.threads, path);
    return h_flex().flex_1().min_h(0).items_start()
      .child(v_flex().id("files").w(narrow ? 150 : 220).flex_none().h_full().p(6).gap(1).border_r(1).border_color(t.border).overflow_y_scrollbar().children(this.files.map((f, i) => {
        const { dir, name } = fileLine(f.path);
        return v_flex().id(`vf-${i}`).w_full().flex_none().px(8).py(5).rounded(6).cursor_pointer().when(i === this.file, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover))
          .on_click((_e, cx) => { this.file = i; cx.notify(); })
          .child(div().w_full().truncate().text_size(12.5).child(name))
          .child(h_flex().w_full().gap(6).text_size(11).child(div().flex_1().min_w(0).truncate().text_color(t.dim).child(dir)).child(div().flex_none().text_color(t.ansi2).child(`+${f.added}`)).child(div().flex_none().text_color(t.ansi1).child(`−${f.removed}`)));
      })))
      .child(v_flex().flex_1().min_w(0).h_full().child(div().flex_1().min_h(0).w_full().relative().font_family(mono()).text_size(11.5)
        .child(div().id("diff-x").size_full().overflow_x_scrollbar().child(div().w_full().min_w(Math.max(400, ...rows.map((l) => (l.text?.length ?? 0) * 7 + 130))).h_full().child(
          v_virtual_list(`diff-${this.file}`, rows.length, 20, (i) => String(i), (r) => rows.slice(r.start, r.end).map((l) => this.viewerRow(l, t))).on_item_click((key, cx) => this.startComment(rows[Number(key)], cx)).size_full())))
        .child(Scrollbar.vertical(`diff-${this.file}`).viewport_from_layout().absolute().inset_0()))
        .child(this.composing ? this.composer(t) : div().w_full().flex_none().px(12).py(5).border_t(1).border_color(t.border).text_size(11).text_color(t.dim).child(tr("comment_hint"))));
  }

  renderViewer(t, cx) {
    const want = shared(VIEW_KEY);
    if (want && want.at !== this.loaded) this.loadViewer(want, cx);
    const target = this.target;
    return v_flex().id("viewer").size_full().on_size_change((size, cx) => { this.size = size; cx.notify(); })
      .child(h_flex().h(42).flex_none().px(14).gap(8).items_center().border_b(1).border_color(t.border)
        .when(Boolean(target), (e) => e
          .child(div().flex_none().font_semibold().child(`#${target.number}`))
          .child(div().min_w(0).truncate().text_color(t.muted).child(target.kind === "log" ? `${target.name} · ${target.title}` : target.title)))
        .child(div().flex_1())
        .when(target?.kind === "diff", (e) => e.child(div().flex_none().text_size(11).text_color(t.ansi2).child(`+${target.additions ?? 0}`)).child(div().flex_none().text_size(11).text_color(t.ansi1).child(`−${target.deletions ?? 0}`)))
        .child(h_flex().id("close").size(26).flex_none().items_center().justify_center().rounded(6).cursor_pointer().hover((s) => s.bg(t.hover)).on_click(() => this.closeViewer()).child(icon("cross", 13, t.muted))))
      .when(Boolean(target), (e) => e.child(this.viewerBody(t)));
  }

  render(cx) {
    this.useLang();
    const t = theme();
    const shell = v_flex().size_full().min_h(0).rounded(10).overflow_hidden().bg(t.background).border_1().border_color(t.border).text_color(t.foreground).text_size(13);
    // A pane already has Herdr's own frame around it.
    if (this.viewer) return v_flex().size_full().min_h(0).overflow_hidden().bg(t.background).text_color(t.foreground).text_size(13).child(this.renderViewer(t, cx));
    const card = this.url ? this.current() : null;
    if (this.url && !card) this.url = null; // it closed while open
    return shell.id("pr-flow").track_focus(this.handle).on_key_down((e, cx) => this.onKey(e, cx)).on_mouse_down("left", () => this.handle.focus())
      .child(this.settingsOpen ? this.settingsScreen(t) : card && this.issueUrl ? this.issueScreen(this.issueUrl, t) : card ? this.detail(card, t) : this.list(t));
  }
}
