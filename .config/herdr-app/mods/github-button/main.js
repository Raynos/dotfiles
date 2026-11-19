// A GitHub button for the right end of the tab bar, drawn like the built-in
// Files and Changes buttons (mods/tabs), which only know about those two. It
// opens the github mod's popup, the same as cmd-g.
// The layout puts this block right after the tab bar's own row ("tab-bar"). The folder was tab-bar-extras until it held only this button.
import { View, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { run, theme } from "herdr";

export default class GitHubButton extends View {
  render() {
    const t = theme();
    return h_flex().size_full().pr(10).gap(3).items_center().bg(t.chrome).border_b(1).border_color(t.border)
      .child(h_flex().id("open-github").h(26).px(8).gap(5).flex_none().items_center().rounded(6)
        .text_size(12).bg(t.chrome).text_color(t.muted)
        .hover(s => s.bg(t.hover)).on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .on_click(() => run("mod.open", { name: "github" }))
        .child(svg("mods/github/icons/pr.svg").size(14)).child("GitHub"));
  }
}
