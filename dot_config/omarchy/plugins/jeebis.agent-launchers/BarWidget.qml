import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "../jeebis.bar/AgentModel.js" as AgentModel

BarWidget {
  id: root
  moduleName: "jeebis.agent-launchers"
  property bool expanded: false
  property bool pointerHeld: false
  property real islandRevealProgress: expanded && !vertical ? 1 : 0
  readonly property var runningKinds: {
    var kinds = ({})
    var clients = Hyprland.toplevels.values
    for (var i = 0; i < clients.length; i++) {
      var kind = AgentModel.kind(clients[i])
      if (kind) kinds[kind] = true
    }
    return kinds
  }
  visible: islandRevealProgress > 0
  clip: true
  implicitWidth: (buttons.implicitWidth + Style.space(3)) * islandRevealProgress
  implicitHeight: visible ? barSize : 0

  Behavior on islandRevealProgress {
    NumberAnimation { duration: 180; easing.type: Easing.InOutCubic }
  }
  function setExpanded(held) {
    if (pointerHeld === held) return
    pointerHeld = held
    if (held) {
      exitTimer.stop()
      expanded = true
    } else exitTimer.restart()
  }
  Timer { id: exitTimer; interval: 100; onTriggered: root.expanded = false }

  function focusOrLaunch(kind) {
    var clients = Hyprland.toplevels.values
    var chosen = null
    var bestRank = Infinity
    for (var i = 0; i < clients.length; i++) {
      var client = clients[i]
      if (AgentModel.kind(client) !== kind) continue
      var ipc = client.lastIpcObject || ({})
      var history = Number(ipc.focusHistoryID)
      var rank = isFinite(history) && history >= 0 ? history : 1000000
      if (!chosen || rank < bestRank) { chosen = client; bestRank = rank }
    }
    if (chosen && chosen.wayland) {
      chosen.wayland.activate()
    } else if (chosen) {
      var address = String(chosen.address || "").toLowerCase().replace(/^0x/, "")
      if (!/^[0-9a-f]+$/.test(address)) return
      Hyprland.dispatch(Hyprland.usingLua
        ? "hl.dsp.focus({ window = 'address:0x" + address + "' })"
        : "focuswindow address:0x" + address)
    } else if (root.bar) {
      root.bar.run("\"$HOME/.local/bin/jeebis-bar-action\" " + kind)
    }
  }

  Row {
    id: buttons
    anchors.right: parent.right
    anchors.rightMargin: Style.space(3)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(3)
    opacity: root.islandRevealProgress

    Repeater {
      model: [ { kind: "chatgpt", name: "ChatGPT" }, { kind: "codex", name: "Codex" } ]
      WidgetButton {
        required property var modelData
        readonly property bool running: root.runningKinds[modelData.kind] === true
        bar: root.bar
        text: modelData.name
        fontSize: Style.font.bodySmall
        foreground: running ? "#dcd7ba" : "#727169"
        tooltipText: modelData.name + (running ? "にフォーカス" : "を起動")
        fixedHeight: root.barSize
        horizontalMargin: 6
        verticalPadding: 0
        onPressed: function(button) {
          if (button === Qt.LeftButton) root.focusOrLaunch(modelData.kind)
        }
      }
    }
  }
}
