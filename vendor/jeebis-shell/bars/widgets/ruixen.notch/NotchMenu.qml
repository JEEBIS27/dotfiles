pragma ComponentBehavior: Bound
import "../../../ShellConfig.js" as ShellConfig
import "../../../ruixen.launcher/extensions/settings" as Settings
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.Commons

PanelWindow {
  id: root
  BatteryPalette { id: batteryPalette }
  property var hostWindow: null
  property string menuType: ""
  property color foreground: "white"
  property var notificationHistory: null
  property bool dnd: false
  signal closeRequested()
  signal dndToggleRequested()
  readonly property bool settingsMenu: menuType === "wifi" || menuType === "audio"
  readonly property var battery: UPower.displayDevice
  readonly property int batteryPercent: battery && battery.isPresent ? Math.round(battery.percentage * 100) : 0
  readonly property bool charging: battery && battery.state === UPowerDeviceState.Charging
  readonly property int remainingSeconds: battery ? (charging ? battery.timeToFull : battery.timeToEmpty) : 0
  readonly property string title: ({wifi:"ネットワーク",audio:"音量",battery:"バッテリー",notifications:"通知"})[menuType] || ""
  function duration(seconds) {
    if (seconds <= 0) return "計算中"
    var minutes = Math.round(seconds / 60)
    return Math.floor(minutes / 60) + "時間 " + (minutes % 60) + "分"
  }

  screen: hostWindow ? hostWindow.screen : null
  anchors { top: true; bottom: true; left: true; right: true }
  visible: menuType !== "" && hostWindow !== null
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "jeebis-notch-menu"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  mask: Region {
    x: 0; y: ShellConfig.collapsedBottom(Style)
    width: root.width; height: Math.max(0, root.height - y)
  }
  onMenuTypeChanged: if (settingsMenu) Qt.callLater(function() { settings.openSectionById(root.menuType) })
  onVisibleChanged: if (visible) Qt.callLater(function() { card.forceActiveFocus() })

  MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
  Rectangle {
    id: card
    x: Math.round((parent.width - width) / 2)
    y: ShellConfig.collapsedBottom(Style) + ShellConfig.notchMenuGap
    width: Math.min(ShellConfig.notchMenuWidth, parent.width - 16)
    height: Math.min(root.menuType === "battery" ? 220 : ShellConfig.notchMenuHeight, parent.height - y - 8)
    color: "#202127"
    radius: ShellConfig.radius
    border.width: 1; border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25)
    focus: true
    Keys.onEscapePressed: root.closeRequested()
    MouseArea { anchors.fill: parent }
    Text {
      x: 16; y: 12
      text: root.title
      color: root.foreground
      font.family: ShellConfig.notchFontFamily
      font.pixelSize: ShellConfig.notchTooltipFontSize + 2
      font.weight: Font.DemiBold
    }
    Text {
      anchors.right: parent.right; anchors.rightMargin: 14; y: 9
      text: "×"; color: root.foreground; font.pixelSize: 20
      MouseArea { anchors.fill: parent; anchors.margins: 5; cursorShape: Qt.PointingHandCursor; onClicked: root.closeRequested() }
    }
    Item {
      id: body
      anchors.fill: parent; anchors.topMargin: 40
      anchors.bottomMargin: 8
      clip: true
      Settings.SettingsContent {
        id: settings
        anchors.fill: parent
        compactMode: true
        visible: root.settingsMenu
        active: root.visible && root.settingsMenu
        textColor: root.foreground
        muted: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.6)
        accent: Color.accent
        fontFamily: ShellConfig.notchFontFamily
        onActiveChanged: if (active) Qt.callLater(function() { settings.openSectionById(root.menuType) })
      }
      Column {
        visible: root.menuType === "battery"
        x: 18; y: 10; width: parent.width - 36; spacing: 14
        Text {
          text: root.batteryPercent + "%"
          color: root.foreground; font.pixelSize: 26
          font.family: ShellConfig.notchFontFamily
        }
        Rectangle {
          width: parent.width; height: 8; radius: 4; color: "#454650"
          Rectangle {
            width: parent.width * root.batteryPercent / 100; height: parent.height
            radius: 4; color: root.charging ? batteryPalette.charging : (root.batteryPercent <= ShellConfig.batteryCriticalThreshold ? batteryPalette.critical : (root.batteryPercent <= ShellConfig.batteryLowThreshold ? batteryPalette.warning : Color.accent))
          }
        }
        Text {
          text: (root.charging ? "充電完了まで " : "残り ") + root.duration(root.remainingSeconds)
          color: root.foreground; font.pixelSize: ShellConfig.notchTooltipFontSize
          font.family: ShellConfig.notchFontFamily
        }
        Row {
          spacing: 6
          Repeater {
            model: [
              {label:"省電力",profile:PowerProfile.PowerSaver},
              {label:"標準",profile:PowerProfile.Balanced},
              {label:"性能",profile:PowerProfile.Performance}
            ]
            Rectangle {
              required property var modelData
              width: (card.width - 48) / 3; height: 30; radius: 8
              visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
              color: PowerProfiles.profile === modelData.profile ? Color.accent : "#3b3c46"
              Text {
                anchors.centerIn: parent; text: parent.modelData.label
                color: PowerProfiles.profile === parent.modelData.profile ? "#161616" : root.foreground
                font.family: ShellConfig.notchFontFamily; font.pixelSize: ShellConfig.notchTooltipFontSize
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: PowerProfiles.profile = parent.modelData.profile
              }
            }
          }
        }
      }
      Column {
        visible: root.menuType === "notifications"
        anchors.fill: parent; anchors.margins: 14; spacing: 10
        Row {
          spacing: 12
          Rectangle {
            width: 132; height: 30; radius: 8; color: "#3b3c46"
            Text { anchors.centerIn: parent; text: root.dnd ? "通知をオン" : "通知を消音"; color: root.foreground; font.pixelSize: ShellConfig.notchTooltipFontSize }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dndToggleRequested() }
          }
          Rectangle {
            width: 92; height: 30; radius: 8; color: "#3b3c46"
            Text { anchors.centerIn: parent; text: "すべて消去"; color: root.foreground; font.pixelSize: ShellConfig.notchTooltipFontSize }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.notificationHistory) root.notificationHistory.clearAll() }
          }
        }
        ListView {
          width: parent.width; height: parent.height - 40; clip: true; spacing: 8
          model: root.notificationHistory ? root.notificationHistory.entries : []
          Text {
            anchors.centerIn: parent
            visible: parent.count === 0
            text: "通知はありません"; color: root.foreground; opacity: 0.6
            font.pixelSize: ShellConfig.notchTooltipFontSize
          }
          delegate: Rectangle {
            required property var modelData
            width: ListView.view.width; height: notificationText.implicitHeight + 20
            radius: 8; color: "#30313a"
            Column {
              id: notificationText
              x: 10; y: 10; width: parent.width - 38; spacing: 4
              Text { width: parent.width; text: modelData.summary || modelData.app || "通知"; color: root.foreground; wrapMode: Text.Wrap; font.pixelSize: ShellConfig.notchTooltipFontSize; font.bold: true }
              Text { width: parent.width; text: modelData.body || ""; textFormat: Text.PlainText; color: root.foreground; opacity: 0.7; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; font.pixelSize: ShellConfig.notchTooltipFontSize }
            }
            MouseArea { anchors.fill: parent; onClicked: { root.notificationHistory.activate(parent.modelData.key); root.closeRequested() } }
            Text {
              anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
              text: "×"; color: root.foreground; font.pixelSize: 16
              MouseArea { anchors.fill: parent; anchors.margins: 4; onClicked: root.notificationHistory.forgetOne(parent.parent.modelData.key) }
            }
          }
        }
      }
    }
  }
}
