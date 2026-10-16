import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
  id: root
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var barConfig: ({})
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null

  property color islandColor: "#e612141b"
  property color islandStroke: "#445f79bb"
  // Kanagawa palette: accent/foreground, cyan, blue, and muted foreground.
  property color accent: "#dcd7ba"
  property color mainText: "#dcd7ba"
  property color dimText: "#727169"
  property color networkColor: "#6a9589"
  property color bluetoothColor: "#7e9cd8"
  property color batteryGreen: "#76946a"
  property color batteryYellow: "#c0a36e"
  property color batteryRed: "#c34043"
  property string dateText: Qt.formatDateTime(new Date(), "yy/MM/dd")
  property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
  readonly property var audioSink: Pipewire.defaultAudioSink
  readonly property var batteryDevice: UPower.displayDevice

  function volumeIcon() {
    if (!audioSink || !audioSink.audio) return ""
    if (audioSink.audio.muted) return ""
    if (audioSink.audio.volume <= 0.001) return ""
    if (audioSink.audio.volume < 0.34) return ""
    return ""
  }
  function batteryIcon() {
    if (batteryDevice && batteryDevice.isPresent && !UPower.onBattery) return ""
    var level = batteryDevice && batteryDevice.isPresent ? batteryDevice.percentage : 0
    if (level >= 0.875) return ""
    if (level >= 0.625) return ""
    if (level >= 0.375) return ""
    if (level >= 0.125) return ""
    return ""
  }
  function batteryColor() {
    var level = batteryDevice && batteryDevice.isPresent ? batteryDevice.percentage : 0
    if (level <= 0.20) return batteryRed
    if (level <= 0.50) return batteryYellow
    return batteryGreen
  }
  function openPanel(target) {
    if (root.shell && typeof root.shell.toggle === "function")
      return root.shell.toggle(target, "{}")
    return false
  }

  function updateClock() {
    var now = new Date()
    dateText = Qt.formatDateTime(now, "yy/MM/dd")
    timeText = Qt.formatDateTime(now, "HH:mm")
  }
  function workspaces() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; ++i) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) < 0) ids.push(id)
    }
    ids.sort(function(a, b) { return a - b })
    return ids
  }
  function workspaceFor(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; ++i) if (values[i].id === id) return values[i]
    return null
  }

  PwObjectTracker { objects: root.audioSink ? [root.audioSink] : [] }

  Timer { interval: 15000; running: true; repeat: true; onTriggered: root.updateClock() }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData
        anchors { top: true; left: true; right: true }
        margins { top: 2; left: 2; right: 2 }
        implicitHeight: 38
        color: "transparent"
        exclusionMode: ExclusionMode.Auto
        WlrLayershell.namespace: "jeebis-islands-bar"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
          id: leftIsland
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: leftRow.implicitWidth + 22
          height: 38
          radius: height / 2
          color: root.islandColor
          border.width: 1
          border.color: root.islandStroke
          RowLayout {
            id: leftRow
            anchors.centerIn: parent
            spacing: 10

            Item {
              Layout.preferredWidth: displayIcon.implicitWidth + 4
              Layout.preferredHeight: 26
              Text {
                id: displayIcon
                anchors.centerIn: parent
                text: ""
                color: "#727169"
                font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 14
              }
              MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.openPanel("omarchy.monitor")
              }
            }
            Item {
              Layout.preferredWidth: networkIcon.implicitWidth + 4
              Layout.preferredHeight: 26
              Text {
                id: networkIcon
                anchors.centerIn: parent
                text: ""
                color: root.networkColor
                font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 14
              }
              MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.openPanel("omarchy.network")
              }
            }
            Item {
              Layout.preferredWidth: bluetoothIcon.implicitWidth + 4
              Layout.preferredHeight: 26
              Text {
                id: bluetoothIcon
                anchors.centerIn: parent
                text: ""
                color: root.bluetoothColor
                font.family: "Font Awesome 7 Brands"; font.pixelSize: 15
              }
              MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.openPanel("omarchy.bluetooth")
              }
            }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 16; color: "#35404b" }
            Item {
              Layout.preferredWidth: audioControl.implicitWidth
              Layout.preferredHeight: 26
              RowLayout {
                id: audioControl
                anchors.centerIn: parent
                spacing: 8
                Text {
                  text: root.volumeIcon()
                  color: "#dcd7ba"
                  font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 14
                }
                Text {
                  text: root.audioSink && root.audioSink.audio ? Math.round(root.audioSink.audio.volume * 100) + "%" : "—"
                  color: "#dcd7ba"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                }
              }
              MouseArea {
                anchors.fill: parent; acceptedButtons: Qt.LeftButton; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.openPanel("omarchy.audio")
                onWheel: function(wheel) {
                  if (!root.audioSink || !root.audioSink.audio) return
                  var audio = root.audioSink.audio
                  audio.volume = Math.max(0, Math.min(1, audio.volume + (wheel.angleDelta.y > 0 ? 0.04 : -0.04)))
                }
              }
            }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 16; color: "#35404b" }
            Item {
              visible: root.batteryDevice && root.batteryDevice.isPresent
              Layout.preferredWidth: batteryControl.implicitWidth
              Layout.preferredHeight: 26
              RowLayout {
                id: batteryControl
                anchors.centerIn: parent
                spacing: 8
                Text {
                  text: root.batteryIcon()
                  color: root.batteryColor()
                  font.family: "Font Awesome 7 Free Solid"; font.pixelSize: 14
                }
                Text {
                  text: root.batteryDevice && root.batteryDevice.isPresent ? Math.round(root.batteryDevice.percentage * 100) + "%" : ""
                  color: root.batteryColor(); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                }
              }
              MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.openPanel("omarchy.power")
              }
            }
          }
        }

        Rectangle {
          id: centerIsland
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: workspaceRow.implicitWidth + 24
          height: 38
          radius: height / 2
          color: root.islandColor
          border.width: 1
          border.color: root.islandStroke
          RowLayout {
            id: workspaceRow
            anchors.centerIn: parent
            spacing: 9
            Repeater {
              model: root.workspaces()
              delegate: Item {
                required property int modelData
                readonly property var workspace: root.workspaceFor(modelData)
                readonly property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData
                readonly property bool occupied: workspace && workspace.toplevels.values.length > 0
                width: 13; height: 20
                Rectangle {
                  anchors.centerIn: parent
                  width: active ? 9 : 7
                  height: width
                  radius: width / 2
                  color: active ? root.accent : occupied ? "#aeb3c2" : "transparent"
                  border.width: occupied || active ? 0 : 1
                  border.color: "#687080"
                  Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                  anchors.fill: parent
                  onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(modelData)])
                }
              }
            }
          }
        }

        Rectangle {
          id: rightIsland
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: dateTimeRow.implicitWidth + 24
          height: 38
          radius: height / 2
          color: root.islandColor
          border.width: 1
          border.color: root.islandStroke
          RowLayout {
            id: dateTimeRow
            anchors.centerIn: parent
            spacing: 9
            Text { text: root.dateText; color: root.dimText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 15; color: "#35404b" }
            Text { text: root.timeText; color: root.mainText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.weight: Font.DemiBold }
          }
        }
      }
    }
  }
}
