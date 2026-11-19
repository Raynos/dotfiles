// Usage limits across every model, at the bottom of the sidebar (main-projects
// layout, block "usage", between the project list and the footer). One row per
// service with limits: its name, plan, when its fullest limit resets, a dot and
// that limit's used %; a click shows every limit as a bar. A click on a limit makes
// it the row's headline and puts it first (shared "over9k.usageHeadline"), until it's
// clicked again. Claude billed by use has no limits: its row has a cost instead,
// and tabs for the period it covers, with a chart by day and model. Local models have
// no limits, so they aren't here.
// Where the numbers come from (this computer):
//   Claude       ~/.cache/over9k/usage/claude.json, saved by Over9k's optional status
//                line (claude-statusline.sh: Options › Session footers, or "Show its
//                limits" here), the only thing Claude Code gives its limits to; plan
//                from ~/.claude.json's oauthAccount.planDisplayName. Billed by use
//                (Bedrock, Vertex, Foundry, an API key: no plan limits; claude.json says
//                which) the row shows cost: api-cost.py next to this file, from the
//                transcripts. Run on each machine, so one billed by use gets its own row.
//   Gemini       ~/.cache/over9k/usage/antigravity.json, written by
//                Antigravity's (over9k/antigravity/agy-statusline.sh, optional: README):
//                gemini-* and 3p-* (Claude and GPT) buckets, and the plan.
//   Codex        the last rate_limits in its newest session file.
// Each is as fresh as that program's last run; a limit whose reset time has
// passed shows 0%. Limits belong to the account, not the computer: Claude's and
// Gemini's come from whichever connected computer saved them last (REMOTE), when
// it's the same Claude account (accountUuid in ~/.claude.json) or Gemini plan. Over9k's Options › Usage (shared "sidebar.options": usage,
// usageClaude, usageCodex, usageGemini) hides the section or a service.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { theme, exec, home, appHome, run, shared, setShared, layout, notify, readTextFile, machines } from "herdr";

const BLOCK = "usage";
// Is this copy the Over9k layout's (its "usage" block above the footer)? Else it
// is the mod on its own, docked at the bottom: one line across the window.
function inLayout() {
  const find = (n) => n && (n.id === BLOCK && n.content?.mod === "over9k-usage" ? n : (n.children ?? []).map(find).find(Boolean));
  return Boolean(find(layout()));
}
const ROW = 28, LIMIT = 20, TABS = 26, GRAPH = 72;

const CODEX = `f=$(ls -t "$HOME"/.codex/sessions/*/*/*/*.jsonl 2>/dev/null | head -n 1); [ -n "$f" ] || exit 0
grep -o '"rate_limits":{.*' "$f" | tail -n 1 | sed 's/^"rate_limits"://' | jq -c '{plan: .plan_type, primary, secondary}' 2>/dev/null`;
const CLAUDE_PLAN = `jq -r '.oauthAccount.planDisplayName // empty' "$HOME/.claude.json" 2>/dev/null`;
const ACCOUNT = `grep -o '"accountUuid": *"[^"]*"' "$HOME/.claude.json" 2>/dev/null | head -n 1 | sed 's/.*"\\([^"]*\\)"$/\\1/'`;
// Another computer's saved limits and Claude account, a line each (empty when missing).
const REMOTE = `u="$HOME/.cache/over9k/usage"; tr -d '\\n' 2>/dev/null < "$u/claude.json"; echo; tr -d '\\n' 2>/dev/null < "$u/antigravity.json"; echo; ${ACCOUNT}`;

// Seconds as "3h 54m", "6d 23h", "12m".
function left(s) {
  s = Math.max(0, Math.round(s));
  return s < 3600 ? `${Math.max(1, Math.floor(s / 60))}m` : s < 86400 ? `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m` : `${Math.floor(s / 86400)}d ${Math.floor((s % 86400) / 3600)}h`;
}
// A window's length in words: 300 minutes is "5 hours", 10080 "7 days".
function windowName(min) {
  if (!min) return "Limit";
  return min % 1440 === 0 ? `${min / 1440}d` : min % 60 === 0 ? `${min / 60}h` : `${min}m`;
}
// "Google AI Ultra" is "Ultra"; "Claude Max" is "Max".
const money = (n) => `$${(n ?? 0).toFixed(2)}`;
const SPEND_TIP = "Estimated from tokens at list prices, not your bill";
// The tabs of a row billed by use: what its chart and headline cover.
const PERIODS = [{ label: "30 days", days: 30, tab: "30d" }, { label: "2 weeks", days: 14, tab: "2w" },
  { label: "1 week", days: 7, tab: "1w" }, { label: "1 day", days: 1, tab: "1d" }];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const dayName = (day) => { const [, m, d] = day.split("-"); return `${MONTHS[m - 1]} ${Number(d)}`; };
const planName = (p) => (p ?? "").replace(/^(google ai|claude|chatgpt)\s+/i, "").replace(/^\w/, (c) => c.toUpperCase()) || null;

// A computer's Claude billed by use (m: a machine, or null for this one), or null if it isn't.
async function apiRow(m) {
  const script = await readTextFile(`${appHome().replace(/\\/g, "/")}/mods/over9k-usage/api-cost.py`).catch(() => null);
  if (!script) return null;
  const options = m ? { on: m } : {};
  const r = await exec("python3", ["-c", script], options).catch(() => null) ?? await exec("python", ["-c", script], options).catch(() => null);
  try {
    const { plan, days } = JSON.parse(r.stdout);
    return { key: m ? `claude:${m}` : "claude", service: "claude", name: "Claude", plan, where: m, days };
  } catch { return null; }
}

// The cost of the last n days, in all and by model (most first).
function spendIn(days, n) {
  const by = {};
  for (const d of days.slice(-n)) for (const [name, cost] of Object.entries(d.models)) by[name] = (by[name] ?? 0) + cost;
  const models = Object.entries(by).map(([name, cost]) => ({ name, cost })).sort((a, b) => b.cost - a.cost);
  return { total: models.reduce((a, x) => a + x.cost, 0), models };
}

async function readJson(path) {
  const r = await exec("cat", [path]).catch(() => null);
  try { return r?.code === 0 ? JSON.parse(r.stdout) : null; } catch { return null; }
}

export default class Usage extends View {
  init(_props, cx) {
    this.services = [];
    this.local = [];
    this.machineRows = {};
    this.remote = {}; // machine -> { claude, agy, account }: its saved limits
    this.fetching = new Set();
    this.open = new Set(shared("over9k.usageOpen") ?? []);
    this.picked = shared("over9k.usageHeadline") ?? {};
    this.height = 0;
    cx.spawn(async (cx) => {
      for (;;) {
        await this.load(cx);
        cx.notify();
        await cx.sleep(30000);
      }
    });
  }

  async load(cx) {
    const dir = `${home()}/.cache/over9k/usage`;
    const claude = await readJson(`${dir}/claude.json`);
    const api = claude?.api || claude?.bedrock ? await apiRow(null) : null;
    const plan = api ? null : (await exec("sh", ["-c", CLAUDE_PLAN]).catch(() => null))?.stdout.trim();
    const account = (await exec("sh", ["-c", ACCOUNT]).catch(() => null))?.stdout.trim() || null;
    const codex = await exec("sh", ["-c", CODEX]).then((r) => JSON.parse(r.stdout || "null")).catch(() => null);
    const agy = await readJson(`${dir}/antigravity.json`);
    this.mine = { claude, api, plan, account, codex, agy };
    this.build();
    this.loadMachines(cx);
  }

  // The newest of this computer's saved limits and the connected computers' that
  // count as the same (same(file)): limits are the account's, saved where it last ran.
  newest(file, key, same) {
    return Object.values(this.remote).map((r) => r[key]).filter((x) => x && same(x))
      .reduce((a, b) => ((b.at ?? 0) > (a?.at ?? 0) ? b : a), file);
  }

  // This computer's rows, from what load() and loadMachines() read.
  build() {
    if (!this.mine) return;
    const now = Date.now() / 1000;
    const out = [];
    // A limit: label, used % (0 once it has reset), seconds to its reset.
    const limit = (label, used, resetsAt) => resetsAt && resetsAt <= now ? { label, used: 0, left: null } : { label, used: Math.max(0, Math.min(100, used ?? 0)), left: resetsAt ? resetsAt - now : null };

    const { api, plan, account, codex } = this.mine;
    if (api) out.push(api);
    else {
      const sub = (x) => !x.api && !x.bedrock && (x.five_hour || x.seven_day);
      const mine = this.mine.claude && sub(this.mine.claude) ? this.mine.claude : null;
      const claude = account ? this.newest(mine, "claude", (x) => sub(x) && x.account === account) : mine;
      if (claude) out.push({ key: "claude", name: "Claude", plan: planName(plan), limits: [
        claude.five_hour && limit("5h", claude.five_hour.used_percentage, claude.five_hour.resets_at),
        claude.seven_day && limit("7d", claude.seven_day.used_percentage, claude.seven_day.resets_at),
      ].filter(Boolean) });
    }
    if (codex) {
      out.push({ key: "codex", name: "Codex", plan: planName(codex.plan), limits: [codex.primary, codex.secondary].filter(Boolean)
        .map((w) => limit(windowName(w.window_minutes), w.used_percent, w.resets_at)) });
    }
    const agy = this.newest(this.mine.agy?.quota ? this.mine.agy : null, "agy", (x) => x.quota && (!this.mine.agy?.plan || x.plan === this.mine.agy.plan));
    if (agy?.quota) {
      const q = agy.quota, at = agy.at ?? now;
      const b = (key, label) => q[key] && limit(label, (1 - (q[key].remaining_fraction ?? 1)) * 100, q[key].reset_in_seconds != null ? at + q[key].reset_in_seconds : null);
      out.push({ key: "gemini", name: "Gemini", plan: planName(agy.plan), limits: [
        b("gemini-5h", "5h"), b("gemini-weekly", "7d"), b("3p-5h", "5h 3rd party"), b("3p-weekly", "7d 3rd party"),
      ].filter(Boolean) });
    }
    this.local = out;
    this.compose();
  }

  // Other machines answer on their own time: one that hangs holds up only its row.
  loadMachines(cx) {
    const ready = (machines() ?? []).filter((m) => m.name && m.layout === "ready").map((m) => m.name);
    for (const m of Object.keys(this.machineRows)) if (!ready.includes(m)) delete this.machineRows[m];
    for (const m of Object.keys(this.remote)) if (!ready.includes(m)) delete this.remote[m];
    for (const m of ready) {
      if (this.fetching.has(m)) continue;
      this.fetching.add(m);
      cx.spawn(async (cx) => {
        const r = await exec("sh", ["-c", REMOTE], { on: m }).catch(() => null);
        const [c, g, account] = (r?.stdout ?? "").split("\n");
        const json = (t) => { try { return t ? JSON.parse(t) : null; } catch { return null; } };
        const claude = json(c);
        const row = claude?.api || claude?.bedrock ? await apiRow(m) : null;
        this.fetching.delete(m);
        if ((machines() ?? []).some((x) => x.name === m && x.layout === "ready")) {
          this.machineRows[m] = row;
          this.remote[m] = { claude: claude && { ...claude, account: account?.trim() || null }, agy: json(g) };
        }
        this.build();
        cx.notify();
      });
    }
    this.compose();
  }

  // This computer's rows, with other machines' after its Claude.
  compose() {
    const at = this.local.findIndex((s) => s.key === "claude") + 1;
    this.all = [...this.local.slice(0, at), ...Object.values(this.machineRows).filter(Boolean), ...this.local.slice(at)];
    this.pick();
  }

  // What Options says to show.
  pick() {
    const o = shared("sidebar.options") ?? {};
    const want = { claude: o.usageClaude !== false, codex: o.usageCodex !== false, gemini: o.usageGemini !== false };
    this.services = o.usage === false ? [] : (this.all ?? []).filter((s) => want[s.service ?? s.key] !== false);
    this.fit();
  }

  // The block's height: every row, plus the open ones' limits.
  fit() {
    if (!inLayout()) return;
    const h = this.services.length ? 6 + this.services.reduce((n, s) => n + ROW + (this.open.has(s.key) ? (s.days ? TABS + GRAPH + Math.max(1, spendIn(s.days, this.period(s).days).models.length) * LIMIT : Math.max(1, s.limits?.length ?? 0) * LIMIT) + 4 : 0), 0) : 0;
    if (h !== this.height) { this.height = h; run("layout.resize", { id: BLOCK, px: h }); }
  }

  toggle(key, cx) {
    if (this.open.has(key)) this.open.delete(key); else this.open.add(key);
    setShared("over9k.usageOpen", [...this.open]);
    this.fit();
    cx.notify();
  }

  // The limit a service's row shows: the one picked for it, or else its fullest.
  headline(s) {
    if (!s.limits?.length) return null;
    return s.limits.find((l) => l.label === this.picked[s.key]) ?? s.limits.reduce((a, b) => (b.used > a.used ? b : a));
  }

  // The tab a row billed by use is on: the one picked for it, or else the day.
  period(s) {
    return PERIODS.find((p) => p.label === this.picked[s.key]) ?? PERIODS[PERIODS.length - 1];
  }

  pickPeriod(key, label, cx) {
    this.picked[key] = label;
    setShared("over9k.usageHeadline", this.picked);
    this.fit();
    cx.notify();
  }

  pickHeadline(key, label, cx) {
    if (this.picked[key] === label) delete this.picked[key]; else this.picked[key] = label;
    setShared("over9k.usageHeadline", this.picked);
    this.fit();
    cx.notify();
  }

  color(t, used) {
    return used >= 80 ? t.ansi1 : used >= 50 ? t.ansi3 : t.ansi2;
  }

  // Claude's limits only reach a status line: on its own, this mod offers to turn
  // on Over9k's (claude-statusline.sh, setup.sh next to this file). Optional.
  setUpClaude(cx) {
    const mods = `${appHome().replace(/\\/g, "/")}/mods`;
    cx.spawn(async (cx) => {
      const r = await exec("sh", [`${mods}/over9k-usage/setup.sh`, "status", "on", `${mods}/over9k-usage/claude-statusline.sh`]).catch(() => null);
      notify(r?.code === 0
        ? { title: "Claude's limits are on their way", body: "They show after Claude Code's next reply, with a status line under its prompt. Agents started from now on get it.", level: "info" }
        : { title: "Couldn't turn on the status line", body: (r?.stderr ?? "").trim() || "Needs sh and jq.", level: "warning" });
      this.checkClaude(cx);
    });
  }

  checkClaude(cx) {
    readTextFile(`${home()}/.claude/settings.json`).then((text) => {
      const ours = /over9k[^/"]*\/claude-statusline\.sh/.test(text ?? "");
      const has = text != null;
      if (ours !== this.claudeOurs || has !== this.claudeHere) { this.claudeOurs = ours; this.claudeHere = has; cx.notify(); }
    }).catch(() => null);
  }

  // On its own: one line across the bottom. Each service's name, plan, its headline
  // limit and when it resets; hover shows every limit.
  strip(t, cx) {
    if (this.claudeChecked !== true) { this.claudeChecked = true; this.checkClaude(cx); }
    const missingClaude = this.claudeHere && !this.claudeOurs && !this.services.some((s) => s.key === "claude");
    return h_flex().size_full().px(12).gap(18).items_center().bg(t.chrome).border_t(1).border_color(t.border).text_size(12)
      .children(this.services.map((s) => {
        const top = this.headline(s);
        const p = s.days && this.period(s), sum = s.days && spendIn(s.days, p.days);
        const all = s.days ? [SPEND_TIP, ...sum.models.map((x) => `${x.name}: ${money(x.cost)}`)].join("\n")
          : (s.limits ?? []).map((l) => `${l.label}: ${Math.round(l.used)}%${l.left != null ? `, resets in ${left(l.left)}` : ""}`).join("\n");
        return h_flex().id(`strip-${s.key}`).flex_none().gap(6).items_center().when(Boolean(all), (el) => el.tooltip(all))
          .child(div().text_color(t.muted).child(s.name))
          .when(Boolean(s.plan), (el) => el.child(div().px(5).py(1).rounded(4).bg(t.raised).text_size(10.5).text_color(t.accent).child(s.plan)))
          .when(Boolean(s.where), (el) => el.child(div().text_size(11).text_color(t.dim).child(s.where)))
          .when(Boolean(s.days), (el) => el.child(div().text_size(11).text_color(t.dim).child(p.tab)).child(div().text_color(t.foreground).child(money(sum.total))))
          .when(Boolean(top), (el) => el.child(div().text_color(this.color(t, top.used)).child(`${Math.round(top.used)}%`))
            .when(top.left != null, (el) => el.child(div().text_size(11).text_color(t.dim).child(left(top.left)))));
      }))
      .when(missingClaude, (el) => el.child(h_flex().id("strip-setup").flex_none().gap(6).items_center().px(7).py(2).rounded(5).cursor_pointer()
        .text_color(t.accent).hover((x) => x.bg(t.hover)).on_click((_e, cx) => this.setUpClaude(cx))
        .tooltip("Turns on Over9k's Claude Code status line, which shows a line under the prompt and saves the limits. Your own comes back when it's off.")
        .child(div().text_color(t.muted).child("Claude")).child("Show its limits")))
      .when(!this.services.length && !missingClaude, (el) => el.child(div().text_color(t.dim).child("No usage yet: start Claude Code, Codex or Antigravity")));
  }

  render(cx) {
    const t = theme();
    const o = JSON.stringify(shared("sidebar.options") ?? {});
    if (o !== this.seenOptions) { this.seenOptions = o; this.pick(); }
    if (!inLayout()) return this.strip(t, cx);
    const dim = (s) => div().text_size(11).text_color(t.dim).child(s);
    return v_flex().w_full().pt(3).px(10).border_t(1).border_color(t.border).bg(t.chrome).text_size(12.5)
      .children(this.services.map((s, i) => {
        const open = this.open.has(s.key);
        const top = this.headline(s);
        const p = s.days && this.period(s), sum = s.days && spendIn(s.days, p.days);
        // A model keeps its colour across the tabs: by its rank over all of them.
        const palette = [t.accent, t.ansi3, t.ansi5, t.ansi6, t.ansi2, t.ansi1];
        const color = (name) => palette[Math.max(0, spendIn(s.days, 30).models.findIndex((x) => x.name === name)) % palette.length];
        const shown = s.days?.slice(-p.days) ?? [];
        const most = Math.max(...shown.map((d) => spendIn([d], 1).total), 0);
        return v_flex().w_full()
          .when(i > 0, (el) => el.border_t(1).border_color(t.border))
          .child(h_flex().id(`usage-${s.key}`).h(ROW).px(4).gap(6).items_center().rounded(6).cursor_pointer()
            .hover((x) => x.bg(t.hover))
            .on_click((_e, cx) => this.toggle(s.key, cx))
            // Name and plan shrink too (the name is cut) once the reset time is gone,
            // so the right side never moves.
            .child(h_flex().min_w(0).flex_shrink(1).gap(6).items_center().overflow_hidden()
              .child(div().min_w(0).truncate().text_color(t.muted).child(s.name))
              .when(Boolean(s.plan), (el) => el.child(div().flex_shrink_0().px(5).py(1).rounded(4).bg(t.raised).text_size(10.5).text_color(t.accent).child(s.plan)))
              .when(Boolean(s.where), (el) => el.child(dim(s.where).min_w(0).truncate())))
            // The reset time gives way first when the sidebar is narrow (cut, then
            // gone); the dot, the % (fixed width, right-aligned) and the arrow stay put.
            .child(h_flex().flex_1().min_w(0).justify_end().overflow_hidden()
              .when(Boolean(s.days), (el) => el.child(dim(p.tab)))
              .when(Boolean(top) && !open && top.left != null, (el) => el.child(h_flex().id(`reset-${s.key}`).min_w(0).gap(3).items_center().tooltip(`Resets in ${left(top.left)}`)
                .child(dim(left(top.left)).min_w(0).truncate()))))
            .when(Boolean(top) && !open, (el) => el
              .child(div().w(32).flex_none().flex().justify_end().text_color(this.color(t, top.used)).child(`${Math.round(top.used)}%`)))
            .when(Boolean(s.days), (el) => el.child(div().id(`spend-${s.key}`).flex_none().pl(6).text_color(t.foreground).tooltip(`Last ${p.label}. ${SPEND_TIP}`).child(money(sum.total))))
            .child(svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`).size(8).flex_none().flex_shrink_0().text_color(t.dim)))
          .when(open && Boolean(s.days), (el) => el.child(v_flex().px(4).pb(4)
            .child(h_flex().h(TABS).pb(4).gap(2).children(PERIODS.map((x) => h_flex().id(`tab-${s.key}-${x.label}`).flex_1().h_full().items_center().justify_center()
              .rounded(4).cursor_pointer().text_size(11).tooltip(`Show the last ${x.label}`)
              .when(x === p, (b) => b.bg(t.raised)).text_color(x === p ? t.foreground : t.muted)
              .hover((b) => b.bg(t.hover))
              .on_click((_e, cx) => this.pickPeriod(s.key, x.label, cx))
              .child(x.tab))))
            // A bar a day, stacked by model. Always 30 slots, filled from the left, so a bar is
            // as wide on every tab. The whole of a slot is its hover, however short its bar;
            // the slots after the last bar show the period's total.
            .child(h_flex().h(GRAPH).pb(4).children([...shown.map((d) => {
              const day = spendIn([d], 1);
              return v_flex().id(`day-${s.key}-${d.day}`).flex_1().h(GRAPH - 4).pr(1).justify_end().hover((b) => b.bg(t.hover))
                .tooltip([`${dayName(d.day)}: ${money(day.total)}`, ...day.models.map((x) => `${x.name}: ${money(x.cost)}`)].join("\n"))
                .when(!day.models.length, (b) => b.child(div().w_full().h(1).flex_none().bg(t.raised)))
                .children(day.models.map((x) => div().w_full().flex_none().bg(color(x.name)).h(Math.max(1, (x.cost / most) * (GRAPH - 4)))));
            }), ...Array.from({ length: 30 - shown.length }, (_, i) => div().id(`rest-${s.key}-${i}`).flex_1().h(GRAPH - 4)
              .tooltip([`Last ${p.label}: ${money(sum.total)}`, ...sum.models.map((x) => `${x.name}: ${money(x.cost)}`)].join("\n")))]))
            .when(!sum.models.length, (el) => el.child(div().h(LIMIT).flex().items_center().text_size(11.5).text_color(t.dim).child("No cost in this period")))
            .children(sum.models.map((x) => h_flex().h(LIMIT).items_center().gap(7).text_size(11.5)
              .child(div().w(7).h(7).flex_none().rounded(4).bg(color(x.name)))
              .child(div().flex_1().min_w(0).truncate().text_color(t.muted).child(x.name))
              .child(div().flex_none().text_color(t.foreground).child(money(x.cost)))))))
          .when(open && Boolean(s.limits), (el) => el.child(v_flex().px(4).pb(4).children([...s.limits].sort((a, b) => (b.label === this.picked[s.key]) - (a.label === this.picked[s.key])).map((l) =>
            h_flex().id(`limit-${s.key}-${l.label}`).h(LIMIT).items_center().gap(7).text_size(11.5).rounded(4).cursor_pointer()
              .hover((x) => x.bg(t.hover))
              .on_click((_e, cx) => this.pickHeadline(s.key, l.label, cx))
              .tooltip(l.label === this.picked[s.key] ? "Unpin as headline number" : "Pin as headline number")
              .child(div().w(82).flex_none().truncate().text_color(l.label === this.picked[s.key] ? t.accent : t.muted).child(l.label))
              .child(div().flex_1().h(3).rounded(2).bg(t.raised)
                .child(div().h(3).rounded(2).bg(this.color(t, l.used)).w(`${Math.max(l.used > 0 ? 3 : 0, l.used)}%`)))
              .child(div().w(30).flex_none().flex().justify_end().text_color(this.color(t, l.used)).child(`${Math.round(l.used)}%`))
              .child(div().w(44).flex_none().flex().justify_end().text_size(10.5).text_color(t.dim).child(l.left != null ? left(l.left) : ""))))));
      }));
  }
}
