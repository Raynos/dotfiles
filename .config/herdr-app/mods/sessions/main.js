// Sessions: tabs across the top of the window, like the TUI's herdr servers
// (bin/herdr-attach). Each session has its own spaces, and with them their
// tabs, panes and agents, and its own color theme. The sidebar (space-folders)
// and the agents list (session-agents) show only the spaces of the session in
// front; this mod decides which session a space is in.
//
// Click a session to go to it (the space you were last in there, or a new one
// if it has none). Right-click one to move the space in front into it.
// A new space joins the session in front, except a space on a machine a
// session claims (mini: the Mac mini), which joins that one. Going to a space
// another way (an agent's notification, a key) brings its session in front.
//
// shared("sessions"): { active, of: { spaceId: session }, last: { session:
// spaceId }, claims: { machine: session } }. Kept in the app's shared.json.

import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { spaces, machines, run, theme, shared, setShared, checking, openOverlay, closeOverlay, props } from "herdr";

// The sessions, left to right. theme: a file in themes/ (dotfiles .config/herdr-app/themes).
const SESSIONS = [
  { name: "personal", theme: "house" },
  { name: "house", theme: "house" },
  { name: "wildshard", theme: "vibe" },
  { name: "games", theme: "vibe" },
  { name: "localai", theme: "vibe" },
  { name: "mini", theme: "vibe", machine: "mini-ts" },
];
const FIRST = "localai";
const RANK = { blocked: 3, done: 2, working: 1 };

const state = () => shared("sessions") ?? {};
const sessionNamed = (name) => SESSIONS.find((s) => s.name === name);
const claimed = (machine) => machine && SESSIONS.find((s) => s.machine === machine);

export default class Sessions extends View {
  init() {
    this.front = null; // the space in front at the last render
    this.applied = null; // the theme last set
  }

  // Give every space a session, forget closed ones, follow the space in front.
  sync() {
    const s = state(), sp = spaces();
    let active = sessionNamed(s.active) ? s.active : FIRST;
    const of = { ...(s.of ?? {}) }, last = { ...(s.last ?? {}) };
    let changed = active !== s.active || !s.claims;
    for (const x of sp) {
      if (sessionNamed(of[x.id])) continue;
      of[x.id] = claimed(x.machine)?.name ?? active;
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
    const claims = Object.fromEntries(SESSIONS.filter((k) => k.machine).map((k) => [k.machine, k.name]));
    if (changed) setShared("sessions", { active, of, last, claims });
    return { active, of, last };
  }

  applyTheme(active) {
    const want = sessionNamed(active)?.theme;
    if (!want || want === this.applied || checking()) return;
    this.applied = want;
    run("app.theme", { name: want });
  }

  go(name) {
    const { of, last } = this.sync();
    const mine = spaces().filter((x) => of[x.id] === name);
    const s = state();
    setShared("sessions", { ...s, active: name });
    const to = mine.find((x) => x.id === last[name]) ?? mine[0];
    if (to) run("space.select", { id: to.id });
    else {
      const machine = sessionNamed(name)?.machine;
      run("space.new", machine ? { machine } : { machine: "" });
    }
  }

  move(name) {
    const front = spaces().find((x) => x.active);
    if (!front) return;
    const s = state();
    setShared("sessions", { ...s, active: name, of: { ...(s.of ?? {}), [front.id]: name }, last: { ...(s.last ?? {}), [name]: front.id } });
  }

  menuView(t) {
    const { menu, overlay } = props();
    const front = spaces().find((x) => x.active);
    const item = (key, label, action) => div().id(key).h(30).px(10).flex().items_center().rounded(6).cursor_pointer()
      .hover((s) => s.bg(t.hover)).on_click(() => { closeOverlay(overlay); action(); }).child(label);
    return v_flex().id("session-menu").size_full().p(5).gap(1).bg(t.popover).text_color(t.foreground).text_size(12.5)
      .when(Boolean(front), (el) => el.child(item("session-move", `Move “${front.name}” to ${menu}`, () => this.move(menu))))
      .child(item("session-new", `New space in ${menu}`, () => {
        setShared("sessions", { ...state(), active: menu });
        const machine = sessionNamed(menu)?.machine;
        run("space.new", machine ? { machine } : { machine: "" });
      }));
  }

  render() {
    const t = theme();
    if (props()?.menu) return this.menuView(t);
    const { active, of } = checking() ? { active: FIRST, of: {} } : this.sync();
    this.applyTheme(active);
    const sp = spaces();
    const tab = (k) => {
      const mine = sp.filter((x) => of[x.id] === k.name);
      const status = mine.map((x) => x.status).reduce((a, b) => ((RANK[b] ?? 0) > (RANK[a] ?? 0) ? b : a), null);
      const on = k.name === active;
      const dot = status && RANK[status] ? (status === "blocked" ? t.blocked : status === "done" ? t.done : t.working) : null;
      return h_flex().id(`session-${k.name}`).h(26).px(12).gap(7).items_center().rounded(7).cursor_pointer()
        .text_size(12.5).text_color(on ? t.foreground : t.muted)
        .when(on, (el) => el.bg(t.selected).font_semibold())
        .when(!on, (el) => el.hover((s) => s.bg(t.hover).text_color(t.foreground)))
        .on_click(() => this.go(k.name))
        .on_mouse_down("right", () => openOverlay({ mod: "sessions", kind: "popup", width: 260, height: 80, props: { menu: k.name } }))
        .when(Boolean(k.machine), (el) => el.child(svg("mods/workspace-chrome/server.svg").size(12).flex_none()))
        .child(k.name)
        .when(mine.length > 0, (el) => el.child(div().text_size(11).text_color(t.dim).child(String(mine.length))))
        .when(Boolean(dot), (el) => el.child(div().size(7).rounded(4).flex_none().bg(dot)));
    };
    // The window's buttons sit at the top left: start after them.
    return h_flex().id("sessions").size_full().pl(84).pr(10).gap(4).items_center().bg(t.chrome)
      .children(SESSIONS.map(tab));
  }
}
