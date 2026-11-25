// Sessions: tabs across the top of the window, like the TUI's herdr servers
// (bin/herdr-attach). Each session has its own spaces, and with them their
// tabs, panes and agents, and its own color theme. The sidebar (space-folders)
// and the agents list (session-agents) show only the spaces of the session in
// front; this mod decides which session a space is in.
//
// The sessions with agents are tabs, in the order you drag them into; the
// rest wait in the menu on the right (the one in front is always a tab).
// A pinned session is always a tab, agents or not, and pinned ones come first
// (top left), in file order.
// Click a session to go to it (the space you were last in there, or a new one
// if it has none: on its machine, if it names one). Right-click one to move
// the space in front into it, or to edit or delete it. New sessions are rare:
// add them to the file below (ask an agent). A new space
// joins the session in front. Going to a space another way (an agent's
// notification, a key) brings its session in front.
//
// The sessions are this computer's own, not the repo's: every machine using
// these dotfiles names its own. They live in ~/.config/herdr-sessions.json,
// outside the app's folder so a Herdr update can't wipe them:
//   { "sessions": [{ "name": "games", "theme": "vibe", "machine": "mini-ts"?, "pinned": true? }] }
// theme: graphite, ink, moss, paper or a file in themes/ (vibe and house come
// with the dotfiles); none leaves the theme alone. Without the file there is
// one session, "main". The file is read again every 5 seconds.
//
// An agent moves spaces between sessions by adding to the file
//   "move": { "<space id from herdr-app ls>": "<session>" }
// which is applied on the next read, then taken out of the file.
//
// Shared state: "sessions.list" (the file, while this runs) and "sessions":
// { active, of: { spaceId: session }, last: { session: spaceId } }, kept in the
// app's shared.json.

import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex, InputState, Input } from "gpui-base";
import { spaces, agents, machines, run, theme, shared, setShared, checking, openOverlay, closeOverlay, props, exec, window } from "herdr";

const FILE = "~/.config/herdr-sessions.json";
const DEFAULT = [{ name: "main" }];
const BUILT_IN = ["graphite", "ink", "moss", "paper"];
const RANK = { blocked: 3, done: 2, working: 1 };

const list = () => shared("sessions.list") ?? DEFAULT;
const state = () => shared("sessions") ?? {};
const named = (name) => list().find((s) => s.name === name);
// Pinned sessions first, each group in file order.
const ordered = () => [...list().filter((s) => s.pinned), ...list().filter((s) => !s.pinned)];
const newSpace = (name) => { const m = named(name)?.machine; run("space.new", { machine: m ?? "" }); };

// { sessions, move } from the file, or null when it's missing or unreadable.
async function readFile() {
  const r = await exec("sh", ["-c", `cat ${FILE} 2>/dev/null`]);
  if (!r.stdout.trim()) return null;
  try {
    const d = JSON.parse(r.stdout);
    const sessions = Array.isArray(d.sessions) ? d.sessions.filter((s) => s?.name) : [];
    return sessions.length ? { sessions, move: d.move && typeof d.move === "object" ? d.move : null } : null;
  } catch { return null; }
}

function saveList(next) {
  setShared("sessions.list", next);
  const text = JSON.stringify({ sessions: next }, null, 2);
  exec("sh", ["-c", `printf '%s\\n' "$1" > ${FILE}.tmp && mv ${FILE}.tmp ${FILE}`, "sh", text]).catch(() => null);
}

export default class Sessions extends View {
  init(_props, cx) {
    const p = props() ?? {};
    if (p.menu) { this.menu = p; return; }
    if (p.more) { this.more = p; return; }
    if ("edit" in p) { this.openEditor(p, cx); return; }
    this.front = null; // the space in front at the last render
    this.applied = null; // the theme last set
    this.loaded = false; // the file has been read: until then spaces keep their sessions
    this.pressed = null; // the session pressed, maybe about to be dragged
    this.drag = null; // once it moves: { x: pointer in the bar, grab: where in the tab it was held }
    this.over = null; // the session under the pointer while dragging
    if (checking()) return;
    this.load(cx, true);
    // The file is edited by hand or by an agent: read it again now and then.
    cx.timer.every(5000, (cx) => this.load(cx, false));
  }

  load(cx, first) {
    cx.spawn(async (cx) => {
      const read = await readFile().catch(() => null);
      const next = read?.sessions ?? (first ? DEFAULT : null);
      if (next && JSON.stringify(next) !== JSON.stringify(shared("sessions.list"))) setShared("sessions.list", next);
      if (read?.move) {
        const s = state(), of = { ...(s.of ?? {}) };
        for (const [id, name] of Object.entries(read.move)) if (read.sessions.some((k) => k.name === name)) of[id] = name;
        // The space in front moved: its new session comes in front with it.
        const front = spaces().find((x) => x.active);
        setShared("sessions", { ...s, of, active: front && read.move[front.id] ? of[front.id] : s.active });
        saveList(read.sessions); // the file again, without "move"
      }
      this.loaded = true;
      cx.notify();
    });
  }

  // ---- the bar ----

  // Give every space a session, forget closed ones, follow the space in front.
  sync() {
    const s = state(), sp = spaces(), all = list();
    let active = named(s.active) ? s.active : all[0].name;
    const of = { ...(s.of ?? {}) }, last = { ...(s.last ?? {}) };
    let changed = active !== s.active;
    for (const x of sp) {
      if (named(of[x.id])) continue;
      of[x.id] = active;
      changed = true;
    }
    // A space gone from a machine whose spaces are all in: closed. (A machine
    // away shows none of its spaces; they keep their session.)
    const ready = new Set(machines().filter((m) => m.layout === "ready").map((m) => m.name ?? ""));
    const ids = new Set(sp.map((x) => x.id));
    for (const id of Object.keys(of)) {
      const machine = id.includes("/") ? id.slice(0, id.indexOf("/")) : "";
      if (!ids.has(id) && ready.has(machine)) { delete of[id]; changed = true; }
    }
    const front = sp.find((x) => x.active);
    if (front && front.id !== this.front) {
      this.front = front.id;
      if (of[front.id] !== active) { active = of[front.id]; changed = true; }
    }
    if (front && of[front.id] === active && last[active] !== front.id) { last[active] = front.id; changed = true; }
    if (changed) setShared("sessions", { active, of, last });
    return { active, of, last };
  }

  applyTheme(active) {
    const want = named(active)?.theme;
    if (!want || want === this.applied || checking()) return;
    this.applied = want;
    run("app.theme", { name: want });
  }

  go(name) {
    const { of, last } = this.sync();
    setShared("sessions", { ...state(), active: name });
    const mine = spaces().filter((x) => of[x.id] === name);
    const to = mine.find((x) => x.id === last[name]) ?? mine[0];
    if (to) run("space.select", { id: to.id });
    else newSpace(name);
  }

  // Agents per session.
  counts(of) {
    const n = {};
    for (const a of agents()) if (of[a.space]) n[of[a.space]] = (n[of[a.space]] ?? 0) + 1;
    return n;
  }

  // A dragged session goes where the one it's dropped on is.
  reorder(from, to) {
    const all = list(), k = all.find((x) => x.name === from);
    // Pinned ones stay first: a drag only reorders within its own group.
    if (!k || from === to || !all.some((x) => x.name === to) || !k.pinned !== !named(to).pinned) return;
    const after = all.findIndex((x) => x.name === from) < all.findIndex((x) => x.name === to);
    const rest = all.filter((x) => x.name !== from);
    const i = rest.findIndex((x) => x.name === to) + (after ? 1 : 0);
    saveList([...rest.slice(0, i), k, ...rest.slice(i)]);
  }

  render() {
    const t = theme();
    if (this.menu) return this.menuView(t);
    if (this.more) return this.moreView(t);
    if (this.editing) return this.editView(t);
    const ready = this.loaded && !checking();
    const { active, of } = ready ? this.sync() : { active: state().active, of: state().of ?? {} };
    if (ready) this.applyTheme(active);
    const sp = spaces(), n = this.counts(of);
    const shown = ordered().filter((k) => k.pinned || n[k.name] || k.name === active);
    const empty = ordered().filter((k) => !shown.some((x) => x.name === k.name));
    const order = shown.map((k) => k.name);
    const dragging = this.pressed !== null && this.drag !== null;
    // What a tab shows; the dragged copy shows the same.
    const content = (el, k, on) => {
      const status = sp.filter((x) => of[x.id] === k.name).map((x) => x.status)
        .reduce((a, b) => ((RANK[b] ?? 0) > (RANK[a] ?? 0) ? b : a), null);
      const dot = status === "blocked" ? t.blocked : status === "done" ? t.done : null;
      return el.h(26).px(12).gap(7).items_center().rounded(7).text_size(12.5)
        .when(Boolean(k.machine), (el) => el.child(svg("mods/workspace-chrome/server.svg").size(12).flex_none()))
        .child(k.name)
        // The agent count, as a badge: a bare number next to the name read like a tab number.
        .when(Boolean(n[k.name]), (el) => el.child(div().h(17).min_w(17).px(5).flex().flex_none().items_center().justify_center()
          .rounded(9).border_1().border_color(on ? t.muted : t.border).bg(on ? t.raised : t.chrome)
          .text_size(10.5).font_semibold().text_color(on ? t.foreground : t.muted).child(String(n[k.name]))))
        .when(status === "working", (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(11).flex_none().text_color(t.working).spin(900)))
        .when(Boolean(dot), (el) => el.child(div().size(7).rounded(4).flex_none().bg(dot)));
    };
    const endDrag = () => { this.pressed = null; this.drag = null; this.over = null; };
    const tab = (k) => {
      const on = k.name === active, held = this.pressed === k.name;
      // Where the dragged tab would land: a line on the side it would go.
      const target = dragging && this.over === k.name && !held;
      const right = target && order.indexOf(this.pressed) < order.indexOf(k.name);
      return content(h_flex().id(`session-${k.name}`).relative().flex_none(), k, on)
        .cursor_pointer().text_color(on ? t.foreground : t.muted)
        .when(on, (el) => el.bg(t.selected).font_semibold())
        .when(!on && !dragging, (el) => el.hover((s) => s.bg(t.hover).text_color(t.foreground)))
        .when(held && dragging, (el) => el.opacity(0.35))
        .when(target, (el) => el.child(div().absolute().top(3).bottom(3).w(2).rounded(1).bg(t.accent)
          .when(right, (l) => l.right(-3)).when(!right, (l) => l.left(-3))))
        .on_mouse_down("left", (e, cx) => {
          cx.stop_propagation();
          this.pressed = k.name;
          this.down = { x: e.position.x, grab: e.local_position?.x ?? 20 };
        })
        .on_mouse_move((_e, cx) => { if (dragging && this.over !== k.name) { this.over = k.name; cx.notify(); } })
        .on_mouse_up("left", (_e, cx) => {
          const from = this.pressed, moved = this.drag !== null;
          endDrag();
          if (!moved) this.go(k.name);
          else if (from && from !== k.name) this.reorder(from, k.name);
          cx.notify();
        })
        .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); openOverlay({ mod: "sessions", kind: "popup", width: 260, height: 160, props: { menu: k.name } }); });
    };
    const stop = (_e, cx) => cx.stop_propagation();
    const more = h_flex().id("session-more").h(26).px(10).gap(6).flex_none().items_center().rounded(7).cursor_pointer()
      .text_size(12.5).text_color(t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", stop)
      .on_click(() => openOverlay({ mod: "sessions", kind: "popup", width: 220, height: 44 + 30 * empty.length, props: { more: true } }))
      .child(`${empty.length} more`).child(svg("mods/workspace-chrome/chevron-down.svg").size(11));
    const held = dragging && shown.find((k) => k.name === this.pressed);
    // The window's buttons sit at the top left: start after them (not in full screen).
    const lights = window()?.fullscreen ? 12 : 84;
    return h_flex().id("sessions").relative().size_full().pl(lights).pr(10).gap(4).items_center().bg(t.chrome)
      .when(dragging, (el) => el.cursor_grabbing())
      // A press becomes a drag once the pointer has moved a few pixels.
      .on_mouse_move((e, cx) => {
        if (this.pressed === null) return;
        if (this.drag === null && Math.abs(e.position.x - (this.down?.x ?? e.position.x)) < 4) return;
        this.drag = { x: e.local_position.x, grab: this.down?.grab ?? 20 };
        cx.notify();
      })
      .on_mouse_up("left", (_e, cx) => { if (this.pressed !== null) { endDrag(); cx.notify(); } })
      // Let go outside the bar: no drop.
      .on_hover((hovered, cx) => { if (!hovered && this.pressed !== null) { endDrag(); cx.notify(); } })
      .children(shown.map(tab))
      .when(empty.length > 0, (el) => el.child(more))
      // The dragged copy, following the pointer.
      .when(Boolean(held), (el) => el.child(content(h_flex().absolute().top(6).left(this.drag.x - this.drag.grab), held, true)
        .bg(t.raised).border_1().border_color(t.accent).text_color(t.foreground).font_semibold().shadow_lg().opacity(0.95)));
  }

  // The sessions without agents (the "more" menu); right-click one for its menu.
  moreView(t) {
    const { overlay } = this.more;
    const of = state().of ?? {}, n = this.counts(of), active = state().active;
    const empty = ordered().filter((k) => !k.pinned && !n[k.name] && k.name !== active);
    return v_flex().id("session-more-menu").size_full().p(5).gap(1).bg(t.popover).text_color(t.foreground).text_size(12.5)
      .child(div().px(10).pt(4).pb(4).text_size(11).text_color(t.dim).child("No agents running"))
      .children(empty.map((k) => h_flex().id(`more-${k.name}`).h(30).px(10).gap(7).items_center().rounded(6).cursor_pointer()
        .hover((s) => s.bg(t.hover))
        .on_click(() => { closeOverlay(overlay); this.go(k.name); })
        .on_mouse_down("right", (_e, cx) => {
          cx.stop_propagation(); closeOverlay(overlay);
          openOverlay({ mod: "sessions", kind: "popup", width: 260, height: 160, props: { menu: k.name } });
        })
        .when(Boolean(k.machine), (el) => el.child(svg("mods/workspace-chrome/server.svg").size(12).flex_none()))
        .child(k.name)));
  }

  // ---- a session's menu (right-click) ----

  move(name) {
    const front = spaces().find((x) => x.active);
    if (!front) return;
    const s = state();
    setShared("sessions", { ...s, active: name, of: { ...(s.of ?? {}), [front.id]: name }, last: { ...(s.last ?? {}), [name]: front.id } });
  }

  menuView(t) {
    const { menu: name, overlay } = this.menu;
    const front = spaces().find((x) => x.active);
    const of = state().of ?? {};
    const empty = !spaces().some((x) => of[x.id] === name);
    const item = (key, label, action) => div().id(key).h(30).px(10).flex().items_center().rounded(6).cursor_pointer()
      .hover((s) => s.bg(t.hover)).on_click(() => { closeOverlay(overlay); action(); }).child(label);
    return v_flex().id("session-menu").size_full().p(5).gap(1).bg(t.popover).text_color(t.foreground).text_size(12.5)
      .when(Boolean(front) && of[front?.id] !== name, (el) => el.child(item("session-move", `Move “${front.name}” here`, () => this.move(name))))
      .child(item("session-new", "New space here", () => { setShared("sessions", { ...state(), active: name }); newSpace(name); }))
      .child(item("session-edit", "Edit session…", () => openOverlay({ mod: "sessions", kind: "dialog", width: 420, props: { edit: name } })))
      .when(empty && list().length > 1, (el) => el.child(item("session-delete", "Delete session", () => saveList(list().filter((k) => k.name !== name)))));
  }

  // ---- adding or editing one (a dialog) ----

  openEditor(p, cx) {
    const k = (p.edit && named(p.edit)) || {};
    this.editing = { was: p.edit, overlay: p.overlay };
    this.theme = k.theme ?? null;
    this.themes = BUILT_IN;
    this.error = null;
    this.name = InputState.new({ value: k.name ?? "", placeholder: "e.g. games" });
    this.machine = InputState.new({ value: k.machine ?? "", placeholder: "optional, e.g. mini-ts" });
    for (const input of [this.name, this.machine]) input.on("submit", (_e, cx) => { this.save(); cx.notify(); });
    if (checking()) return;
    cx.spawn(async (cx) => {
      const r = await exec("sh", ["-c", "ls ~/.config/herdr-app/themes 2>/dev/null"]).catch(() => ({ stdout: "" }));
      const files = r.stdout.split("\n").filter((f) => f.endsWith(".json")).map((f) => f.slice(0, -5));
      this.themes = [...new Set([...files, ...BUILT_IN])];
      cx.notify();
    });
  }

  save() {
    const { was, overlay } = this.editing;
    const name = this.name.value().trim(), machine = this.machine.value().trim() || undefined;
    if (!name) { this.error = "Give it a name."; return; }
    if (name !== was && named(name)) { this.error = `There is already a session called ${name}.`; return; }
    const old = (was && named(was)) || {};
    const entry = { name, ...(this.theme ? { theme: this.theme } : {}), ...(machine ? { machine } : {}), ...(old.pinned ? { pinned: true } : {}) };
    const all = list();
    saveList(was ? all.map((k) => (k.name === was ? entry : k)) : [...all, entry]);
    // A renamed session keeps its spaces.
    if (was && was !== name) {
      const s = state(), ren = (v) => (v === was ? name : v);
      const of = Object.fromEntries(Object.entries(s.of ?? {}).map(([id, v]) => [id, ren(v)]));
      const last = Object.fromEntries(Object.entries(s.last ?? {}).map(([k, v]) => [ren(k), v]));
      setShared("sessions", { ...s, active: ren(s.active), of, last });
    }
    closeOverlay(overlay);
  }

  editView(t) {
    const { was, overlay } = this.editing;
    const button = (key, label, primary, action) => h_flex().id(key).h(32).px(14).flex_none().items_center().rounded(8).border_1()
      .border_color(primary ? t.solid : t.input).bg(primary ? t.solid : t.raised).text_color(primary ? t.solid_foreground : t.foreground)
      .text_size(12.5).font_medium().cursor_pointer().hover((s) => s.opacity(0.88)).on_click(action).child(label);
    const field = (label, input, hint) => v_flex().gap(6)
      .child(div().text_size(12).font_medium().text_color(t.muted).child(label))
      .child(div().h(34).px(10).flex().items_center().rounded(8).border_1().border_color(t.input).bg(t.background)
        .child(Input.new(input).w_full().text_size(13).text_color(t.foreground)))
      .when(Boolean(hint), (el) => el.child(div().text_size(11.5).text_color(t.dim).child(hint)));
    const chip = (name, label) => div().id(`theme-${name ?? "none"}`).h(26).px(10).flex().items_center().rounded(13).cursor_pointer()
      .text_size(12).border_1().border_color(this.theme === name ? t.accent : t.input)
      .text_color(this.theme === name ? t.foreground : t.muted).hover((s) => s.text_color(t.foreground))
      .on_click((_e, cx) => { this.theme = name; cx.notify(); }).child(label);
    return v_flex().id("session-edit").w_full().p(20).gap(16).bg(t.popover).text_color(t.foreground)
      .on_key_down((e, cx) => { if (e.key === "escape") { closeOverlay(overlay); cx.stop_propagation(); } })
      .child(div().text_size(15).font_semibold().child(was ? "Edit session" : "New session"))
      .child(field("Name", this.name, null))
      .child(v_flex().gap(6)
        .child(div().text_size(12).font_medium().text_color(t.muted).child("Theme"))
        .child(h_flex().flex_wrap().gap(6).child(chip(null, "none")).children(this.themes.map((n) => chip(n, n)))))
      .child(field("Machine", this.machine, "Where its first space opens (hc machine ls); empty is this computer."))
      .when(Boolean(this.error), (el) => el.child(div().text_size(12).text_color(t.blocked).child(this.error)))
      .child(h_flex().pt(4).gap(8).justify_end()
        .child(button("session-cancel", "Cancel", false, () => closeOverlay(overlay)))
        .child(button("session-save", "Save", true, (_e, cx) => { this.save(); cx.notify(); })));
  }
}
