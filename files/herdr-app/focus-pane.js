import { View, div } from "gpui-kit";
import { closeOverlay, focused, props, run } from "herdr";

// mod.open is a public key action. This non-interactive overlay lives for one
// event turn so focused() observes the result of the queued pane.go command.
export default class FocusPane extends View {
  init(_props, cx) {
    const overlay = props()?.overlay;
    if (!overlay) return;

    const before = focused();
    if (!before?.pane) {
      closeOverlay(overlay);
      return;
    }
    run("pane.go", { direction: "@vertical@" });
    cx.timer.after(0, () => {
      const after = focused();
      closeOverlay(overlay);
      if (after?.tab === before.tab && after.pane === before.pane) {
        run("pane.go", { direction: "@horizontal@" });
      }
    });
  }

  render() { return div(); }
}
