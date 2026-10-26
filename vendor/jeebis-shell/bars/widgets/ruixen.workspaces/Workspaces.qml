import "../../../ShellConfig.js" as ShellConfig
import "JeebisWorkspaceOrder.js" as WorkspaceOrder
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// GNOME/Ubuntu-style workspace switcher -- small dots for inactive
// workspaces, the focused one stretching into a wider horizontal pill,
// instead of the real omarchy.workspaces' numbered digits. Per direct
// request ("swap from digits to like the linux kinda one with the dots
// and bar... i think it will look better more softer").
//
// Reads the exact same real data/dispatch mechanism as
// omarchy.workspaces (confirmed by reading that file directly:
// /usr/share/omarchy/shell/plugins/bar/widgets/Workspaces.qml) --
// Quickshell.Hyprland's own workspaces/focusedWorkspace, hyprctl
// dispatch to focus. Own plugin, not an edit to that file, because
// omarchy.workspaces is Omarchy-owned (wiped on every omarchy-update,
// never a customization target per this project's own standing rule) --
// the underlying logic didn't need reinventing, just a different
// rendering of the same state.
BarWidget {
  id: root
  moduleName: "ruixen.workspaces"
  property int dragWorkspace: 0
  property int dropWorkspace: 0
  function workspaceAt(point) {
    if (point.y < -10 || point.y > row.height + 10) return 0
    for (var i = 0; i < workspaceRepeater.count; i++) {
      var item = workspaceRepeater.itemAt(i)
      if (item && point.x >= item.x - 4 && point.x <= item.x + item.width + 4) return item.workspaceNumber
    }
    return 0
  }
  function swapWorkspaces(source, target) {
    var code = WorkspaceOrder.swapScript(source, target)
    if (!code || workspaceSwap.running) return
    workspaceSwap.command = ["hyprctl", "eval", code]
    workspaceSwap.running = true
  }
  Process { id: workspaceSwap; onExited: Hyprland.refreshToplevels() }

  // White-theme-only override for the focused pill (see its own color
  // binding below) -- direct report after shipping that hardcoded
  // everywhere: "i switch backed to aura and the workspace slider is
  // stuck on white now... it should still be accent color from theme
  // except for that white theme." Watches the same plain-slug state
  // file `omarchy theme current` itself reads
  // (~/.local/state/omarchy/current/theme.name), not colors.toml's own
  // mode -- Rose Pine is dark-mode but shares White's own low-contrast-
  // accent-on-black-pill problem, but nothing else reported that one
  // broken yet, so this stays scoped to the one theme actually reported
  // instead of guessing at a second.
  property string themeSlug: "unknown"
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.themeSlug = text().trim()
    onLoadFailed: root.themeSlug = "unknown"
    onFileChanged: reload()
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  property real workspaceCpuBusyThreshold: ShellConfig.workspaceCpuBusyThreshold
  property real workspaceCpuResetThreshold: ShellConfig.workspaceCpuResetThreshold
  property var workspaceCpuTicks: ({})
  property var busySamplesByWorkspace: ({})
  property var busyWorkspaces: ({})
  property var workspaceCpuUsage: ({})
  property var launchingWorkspaces: ({})
  property double previousWorkspaceSampleAt: -1
  property int spinnerFrame: 0
  readonly property string spinnerFrames: "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  readonly property var activeWorkspaceIds: workspaceIds()
  function updateWorkspaceCpu(output) {
    var snapshot
    try { snapshot = JSON.parse(String(output)) } catch (error) { return }
    if (!snapshot || !snapshot.workspaces) return

    var now = Date.now()
    var elapsed = root.previousWorkspaceSampleAt > 0
      ? Math.max(0.1, (now - root.previousWorkspaceSampleAt) / 1000)
      : 0
    var tickRate = Number(snapshot.tickRate) || 100
    var nextTicks = ({})
    var nextSamples = ({})
    var nextBusy = ({})
    var nextUsage = ({})
    var ids = root.activeWorkspaceIds

    for (var i = 0; i < ids.length; i++) {
      var key = String(ids[i])
      var ticks = Number(snapshot.workspaces[key]) || 0
      var previousTicks = Number(root.workspaceCpuTicks[key]) || 0
      var samples = Number(root.busySamplesByWorkspace[key]) || 0
      var busy = root.busyWorkspaces[key] === true

      if (elapsed > 0) {
        var cpuPercent = Math.max(0, (ticks - previousTicks) / tickRate / elapsed * 100)
        nextUsage[key] = cpuPercent
        if (cpuPercent >= root.workspaceCpuBusyThreshold) {
          samples = Math.min(samples + 1, 2)
          if (samples >= 2) busy = true
        } else if (cpuPercent < root.workspaceCpuResetThreshold) {
          samples = 0
          busy = false
        }
      }

      nextTicks[key] = ticks
      nextSamples[key] = samples
      nextBusy[key] = busy
    }

    root.workspaceCpuTicks = nextTicks
    root.busySamplesByWorkspace = nextSamples
    root.busyWorkspaces = nextBusy
    root.workspaceCpuUsage = nextUsage
    root.previousWorkspaceSampleAt = now
  }

  function setLaunchPulse(workspaceId, active) {
    var key = String(workspaceId)
    var next = Object.assign({}, root.launchingWorkspaces)
    if (active) next[key] = true
    else delete next[key]
    root.launchingWorkspaces = next
  }

  function hasActiveSpinner() {
    var busyIds = Object.keys(root.busyWorkspaces)
    for (var i = 0; i < busyIds.length; i++) if (root.busyWorkspaces[busyIds[i]]) return true
    var launchingIds = Object.keys(root.launchingWorkspaces)
    for (var j = 0; j < launchingIds.length; j++) if (root.launchingWorkspaces[launchingIds[j]]) return true
    return false
  }

  function handleHyprlandEvent(event) {
    if (!event || event.name !== "openwindow") return

    var parts = event.parse ? event.parse(4) : String(event.data || "").split(",")
    // Hyprland's openwindow payload is address, workspace, class, title.
    var openedWorkspace = parseInt(parts[1], 10)
    if (!isFinite(openedWorkspace)) return
    for (var i = 0; i < workspaceRepeater.count; i++) {
      var button = workspaceRepeater.itemAt(i)
      if (button && button.modelData === openedWorkspace) {
        button.pulseLaunch()
        return
      }
    }
  }

  Process {
    id: workspaceCpuProcess
    command: ["python3", Qt.resolvedUrl("workspace-cpu.py").toString().replace(/^file:\/\//, "")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateWorkspaceCpu(text)
    }
  }

  Timer {
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!workspaceCpuProcess.running) workspaceCpuProcess.running = true
  }

  Timer {
    interval: ShellConfig.workspaceActivity.cyclingMs
    running: root.visible && root.hasActiveSpinner()
    repeat: true
    onTriggered: root.spinnerFrame = (root.spinnerFrame + 1) % root.spinnerFrames.length
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.handleHyprlandEvent(event) }
  }


  // Every position corresponds to its workspace number, including gaps.
  function workspaceIds() {
    var maximum = Math.max(0, Math.floor(Number(ShellConfig.workspaceMinimumCount) || 0))
    var focused = Hyprland.focusedWorkspace
    if (focused && focused.id > 0) maximum = Math.max(maximum, focused.id)
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id > 0) maximum = Math.max(maximum, values[i].id)
    }
    var ids = []
    for (var id = 1; id <= maximum; ++id) ids.push(id)
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // Scroll-to-switch: direction -1 steps to the previous workspace in the
  // list, +1 to the next, wrapping at either end. Same angleDelta.y sign
  // convention as ruixen.media's scroll-to-skip (positive/scroll-up ->
  // previous, negative/scroll-down -> next).
  function cycleWorkspace(direction) {
    var ids = root.workspaceIds()
    if (ids.length === 0) return
    var current = Hyprland.focusedWorkspace
    var idx = current === null ? -1 : ids.indexOf(current.id)
    if (idx === -1) idx = 0
    var next = (idx + direction + ids.length) % ids.length
    root.focusWorkspace(ids[next])
  }

  // The one resolved color for "active, or has real content" -- see
  // its own call site's comment for the White-theme override reasoning.
  readonly property color focusedColor: root.themeSlug === "white" ? root.bar.barForeground : Color.accent

  // Dot/pill geometry -- classic GNOME Shell look: small round dots,
  // the focused one stretches into a horizontal capsule instead of
  // just changing color or swapping a glyph.
  // Grown 8->11 / 20->30 / 6->9, plus real side padding added (was
  // relying entirely on Bar.qml's own workspacesPill outer inset) --
  // per direct feedback ("a bit compact... bigger fat bar and some
  // side padding to the start and end").
  readonly property int dotSize: 11
  readonly property real pillWidth: Math.max(dotSize, ShellConfig.workspaceActiveWidth)
  readonly property int itemSpacing: 9
  readonly property int sidePadding: 8

  ListModel { id: workspaceModel }
  readonly property var workspaceNumbers: workspaceIds()
  onWorkspaceNumbersChanged: syncWorkspaceModel()
  Component.onCompleted: syncWorkspaceModel()
  function syncWorkspaceModel() {
    var ids = workspaceNumbers
    while (workspaceModel.count > ids.length) workspaceModel.remove(workspaceModel.count - 1)
    for (var i = workspaceModel.count; i < ids.length; ++i) workspaceModel.append({ workspaceNumber: ids[i] })
  }
  implicitWidth: row.implicitWidth + sidePadding * 2
  Behavior on implicitWidth { NumberAnimation { duration: ShellConfig.workspaceResizeDuration; easing.type: Easing.InOutCubic } }
  implicitHeight: row.implicitHeight

  Row {
    id: row
    anchors.left: parent.left
    anchors.leftMargin: root.sidePadding
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.itemSpacing

    Repeater {
      id: workspaceRepeater
      model: workspaceModel

      Item {
        id: indicator
        required property int workspaceNumber
        readonly property int modelData: workspaceNumber
        property real entryProgress: 0
        Component.onCompleted: entryProgress = 1
        opacity: entryProgress
        scale: entryProgress
        Behavior on entryProgress { NumberAnimation { duration: ShellConfig.workspaceResizeDuration; easing.type: Easing.InOutCubic } }
        property bool launchPulse: false
        readonly property bool busy: launchPulse || root.busyWorkspaces[String(modelData)] === true
        function pulseLaunch() { launchPulse = true; root.setLaunchPulse(modelData, true); launchPulseTimer.restart() }
        Component.onDestruction: if (launchPulse) root.setLaunchPulse(modelData, false)
        Timer {
          id: launchPulseTimer
          interval: ShellConfig.workspaceActivity.settlingMs
          onTriggered: { indicator.launchPulse = false; root.setLaunchPulse(indicator.modelData, false) }
        }

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        width: focused ? root.pillWidth : root.dotSize
        height: root.dotSize
        anchors.verticalCenter: parent.verticalCenter

        Behavior on width { NumberAnimation { duration: ShellConfig.workspaceResizeDuration; easing.type: Easing.InOutCubic } }

        Rectangle {
          visible: !indicator.busy
          anchors.fill: parent
          radius: ShellConfig.radius
          // Active: full accent. Occupied: previous empty-state tint. Empty: outline only.
          readonly property color inactiveColor: Qt.rgba(root.focusedColor.r, root.focusedColor.g, root.focusedColor.b, 0.35)
          color: indicator.focused ? root.focusedColor : (indicator.occupied ? inactiveColor : "transparent")
          border.width: !indicator.focused && !indicator.occupied ? 1 : 0
          border.color: inactiveColor
          antialiasing: true
          Behavior on color { ColorAnimation { duration: 180 } }
        }

        Rectangle {
          anchors.fill: parent
          anchors.margins: -3
          radius: ShellConfig.radius
          color: "transparent"
          border.width: 1
          border.color: root.focusedColor
          visible: root.dropWorkspace === indicator.modelData && root.dragWorkspace !== root.dropWorkspace
        }
        Text {
          anchors.centerIn: parent
          // Jeebis: braille glyphs sit above the visual centre of the dots.
          anchors.verticalCenterOffset: ShellConfig.workspaceSpinnerOffsetY
          visible: indicator.busy
          text: root.spinnerFrames.charAt(root.spinnerFrame)
          color: root.focusedColor
          font.family: ShellConfig.notchFontFamily
          font.pixelSize: 15
        }
        MouseArea {
          anchors.fill: parent
          // Small dots need a much bigger real hit target than their
          // own visual size -- same -N margin pattern used throughout
          // this project's other small-icon click targets.
          anchors.margins: -6
          cursorShape: Qt.PointingHandCursor
          preventStealing: true
          property point origin
          property bool dragging: false
          onPressed: function(mouse) { origin = Qt.point(mouse.x, mouse.y); dragging = false }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            if (Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y) > Qt.styleHints.startDragDistance) {
              dragging = true
              root.dragWorkspace = indicator.modelData
              root.dropWorkspace = root.workspaceAt(mapToItem(row, mouse.x, mouse.y))
            }
          }
          onReleased: {
            if (dragging && root.dropWorkspace) root.swapWorkspaces(root.dragWorkspace, root.dropWorkspace)
            root.dragWorkspace = 0; root.dropWorkspace = 0
          }
          onClicked: if (!dragging) root.focusWorkspace(indicator.modelData)
          onCanceled: { dragging = false; root.dragWorkspace = 0; root.dropWorkspace = 0 }
        }
      }
    }
  }

  // Wheel -> switch workspace. A wheel-only MouseArea laid over the whole
  // pill as a sibling of Row, declared after it so it sits on top, but
  // acceptedButtons: NoButton means it takes no presses -- the dots'
  // own MouseAreas underneath still get every click. Same pattern as
  // ShelfContent.qml's stripWheel.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: (wheel) => {
      var dy = wheel.angleDelta.y + wheel.pixelDelta.y
      if (dy === 0) return
      root.cycleWorkspace(dy > 0 ? -1 : 1)
    }
  }
}
