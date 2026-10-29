import "../../../motion" as Motion
import "../../../ShellConfig.js" as ShellConfig
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "ruixen.load"

  property real cpuUsage: 0
  property real memoryUsage: 0
  property string loadAverage: "—"
  property bool hasCpuSample: false
  property double previousCpuIdle: -1
  property double previousCpuTotal: -1
  property int cpuCount: 1
  readonly property real cpuHighThreshold: ShellConfig.cpuHighThreshold
  readonly property real memoryHighThreshold: ShellConfig.memoryHighThreshold
  readonly property bool cpuHigh: root.hasCpuSample && root.cpuUsage >= root.cpuHighThreshold
  readonly property bool memoryHigh: root.memoryUsage >= root.memoryHighThreshold
  readonly property bool loadHigh: isFinite(Number(root.loadAverage)) && Number(root.loadAverage) >= root.cpuCount
  readonly property bool highLoad: root.cpuHigh || root.memoryHigh || root.loadHigh
  readonly property var highMetrics: {
    var result = []
    if (root.cpuHigh) result.push({ label: "CPU", value: root.cpuUsage + "%" })
    if (root.memoryHigh) result.push({ label: "RAM", value: root.memoryUsage + "%" })
    if (root.loadHigh) result.push({ label: "LOAD", value: root.loadAverage })
    return result
  }
  // Retain the final high-load readings until the island has animated out.
  property var displayedMetrics: []
  onHighMetricsChanged: if (highMetrics.length > 0) displayedMetrics = highMetrics
  Component.onCompleted: if (highMetrics.length > 0) displayedMetrics = highMetrics

  readonly property color normalColor: Color.muted
  readonly property color highLoadColor: Color.urgent
  readonly property color statusColor: root.highLoadColor
  readonly property real itemSpacing: Style.space(2)

  readonly property bool islandRequested: !vertical && highLoad
  property real islandRevealProgress: islandRequested ? 1 : 0
  property real contentWidth: content.implicitWidth

  visible: islandRevealProgress > 0
  clip: true
  implicitWidth: contentWidth * islandRevealProgress
  implicitHeight: visible ? barSize : 0

  Behavior on islandRevealProgress {
    Motion.JeebisNumberAnimation { bounded: true; baseDuration: root.islandRequested ? ShellConfig.loadIsland.enteringMs : ShellConfig.loadIsland.leavingMs; }
  }
  Behavior on contentWidth {
    Motion.JeebisNumberAnimation { baseDuration: ShellConfig.loadIsland.resizingMs; }
  }

  function updateStats(output) {
    var lines = String(output).split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].trim().split(/\s+/)
      if (fields[0] === "cpu" && fields.length >= 3) {
        var idle = Number(fields[1])
        var total = Number(fields[2])
        if (isFinite(idle) && isFinite(total)) {
          if (root.previousCpuTotal >= 0 && total > root.previousCpuTotal) {
            var deltaTotal = total - root.previousCpuTotal
            var deltaIdle = idle - root.previousCpuIdle
            root.cpuUsage = Math.max(0, Math.min(100, Math.round(100 * (deltaTotal - deltaIdle) / deltaTotal)))
            root.hasCpuSample = true
          }
          root.previousCpuIdle = idle
          root.previousCpuTotal = total
        }
      } else if (fields[0] === "memory" && fields.length >= 2) {
        var memory = Number(fields[1])
        if (isFinite(memory)) root.memoryUsage = Math.round(memory)
      } else if (fields[0] === "load" && fields.length >= 2) {
        root.loadAverage = fields[1]
      }
    }
  }

  Process {
    id: statsProcess
    command: ["omarchy-system-stats", "--bar-widget"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateStats(text)
    }
  }

  Process {
    id: cpuCountProcess
    command: ["nproc"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var count = parseInt(text.trim(), 10)
        if (isFinite(count) && count > 0) root.cpuCount = count
      }
    }
    Component.onCompleted: running = true
  }

  Timer {
    interval: 2500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statsProcess.running) statsProcess.running = true
  }

  Row {
    id: content
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.itemSpacing
    opacity: root.islandRevealProgress
    scale: 0.9 + 0.1 * root.islandRevealProgress
    transformOrigin: Item.Left

    Repeater {
      model: root.displayedMetrics

      delegate: Row {
        required property var modelData
        required property int index
        spacing: root.itemSpacing

        Rectangle {
          visible: index > 0
          width: visible ? 1 : 0
          height: Style.space(16)
          color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, 0.45)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: modelData.label
          color: root.statusColor
          font.family: root.bar ? root.bar.fontFamily : "monospace"
          font.pixelSize: Style.font.bodySmall
          verticalAlignment: Text.AlignVCenter
        }
        Text {
          text: modelData.value
          color: root.statusColor
          font.family: root.bar ? root.bar.fontFamily : "monospace"
          font.pixelSize: Style.font.body
          font.weight: Font.DemiBold
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
  }
}
