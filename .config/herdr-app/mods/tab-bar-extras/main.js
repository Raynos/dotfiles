// Extra buttons for the right end of the tab bar, drawn like the built-in Files
// and Changes buttons (mods/tabs), which only know about those two panels.
//   PRs     shows the pr-flow mod in the same right-hand panel stack
//           ("panel-body"), or closes the panel when PRs is already showing.
//   GitHub  opens the github mod's popup, the same as cmd-g.
// The layout puts this block right after the tab bar's own row ("tab-bar").
import { View, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { run, theme, layout } from "herdr";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

export default class TabBarExtras extends View {
  render() {
    const t = theme();
    const root = layout(), panel = find(root, "panel"), body = find(root, "panel-body");
    const prsOn = panel && !panel.hidden && body?.active === "pr-flow";
    const button = (id, label, icon, on, click) =>
      h_flex().id(id).h(26).px(8).gap(5).flex_none().items_center().rounded(6)
        .text_size(12).bg(on ? t.selected : t.chrome).text_color(on ? t.foreground : t.muted)
        .hover(s => s.bg(t.hover)).on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .on_click(click).child(svg(icon).size(14)).child(label);
    return h_flex().size_full().pr(10).gap(3).items_center().bg(t.chrome).border_b(1).border_color(t.border)
      .child(button("panel-pr-flow", "PRs", "mods/pr-flow/merge.svg", prsOn, () => {
        if (prsOn) run("layout.hide", { id: "panel" });
        else { run("layout.select", { stack: "panel-body", child: "pr-flow" }); run("layout.show", { id: "panel" }); }
      }))
      .child(button("open-github", "GitHub", "mods/github/icons/pr.svg", false, () => run("mod.open", { name: "github" })));
  }
}
