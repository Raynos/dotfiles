// Every new space starts as two terminals side by side.
//
// Herdr has no "panes per new space" setting, so this mod watches spaces()
// and splits a space right once, the first time it shows up with a single tab
// holding a single pane. It draws nothing: the main-folders layout gives it a
// zero-width block in the tab bar row, which keeps it alive.
//
// Spaces that existed before the mod started are left alone, and so are
// spaces that appear because their machine's layout just loaded (a remote
// machine coming online, or the app starting): only spaces made while their
// machine was already loaded count as new.
import { View, div } from "gpui-kit";
import { checking, machines, panes, run, spaces } from "herdr";

const key = (machine) => machine ?? "";

export default class TwoPaneSpaces extends View {
  init() {
    this.seen = new Set(spaces().map((s) => s.id));
    this.ready = this.readyMachines();
  }

  readyMachines() {
    return new Set(machines().filter((m) => m.layout === "ready").map((m) => key(m.name)));
  }

  render() {
    if (!checking()) this.splitNewSpaces();
    return div().size_0();
  }

  splitNewSpaces() {
    const wasReady = this.ready;
    this.ready = this.readyMachines();
    for (const space of spaces()) {
      if (this.seen.has(space.id)) continue;
      if (!wasReady.has(key(space.machine))) {
        this.seen.add(space.id); // loaded, not made: leave it as it is
        continue;
      }
      const tab = space.tabs[0];
      if (!tab || tab.panes === 0) continue; // its first terminal isn't there yet
      this.seen.add(space.id);
      if (space.tabs.length !== 1 || tab.panes !== 1) continue;
      const pane = panes().find((p) => p.tab === tab.id);
      if (pane) run("pane.split", { pane: pane.pane, direction: "right" });
    }
  }
}
