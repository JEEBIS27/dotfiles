pragma ComponentBehavior: Bound
import "../../../ShellConfig.js" as ShellConfig
import QtQuick
import qs.Commons
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

Item {
  id: root
  property color foreground: "white"
  signal dashboardRequested()
  property var hostWindow: null
  property var notificationHistory: null
  property bool dnd: false
  signal dndToggleRequested()
  property string activeMenu: ""
  onVisibleChanged: if (!visible) { activeMenu = ""; hoverTarget = "" }
  readonly property int unreadCount: notificationHistory ? notificationHistory.entries.filter(function(n) { return n.unread }).length : 0
  property string hoverTarget: ""
  readonly property string tooltipText: {
    if (hoverTarget === "clock") return Qt.formatDateTime(clock.date, "yyyy-MM-dd HH:mm:ss t (UTCttt)")
    if (hoverTarget === "network") return wired ? "有線接続" : (network ? "Wi-Fi 信号 " + Math.round(network.signalStrength * 100) + "%" : "ネットワーク未接続")
    if (hoverTarget === "battery") return "バッテリー " + batteryPercent + "%" + (charging ? "（充電中）" : "")
    if (hoverTarget === "notifications") return "未読通知 " + unreadCount + "件" + (dnd ? "（消音中）" : "")
    if (hoverTarget === "volume") return "音量 " + volumePercent + "%" + (muted ? "（ミュート）" : "")
    return ""
  }
  function openMenu(id) {
    hoverTarget = ""
    var type = ({"omarchy.network":"wifi", "omarchy.power":"battery", "omarchy.audio":"audio", "notifications":"notifications"})[id]
    activeMenu = activeMenu === type ? "" : type
  }

  readonly property var devices: Networking.devices ? Networking.devices.values : []
  readonly property var wifi: {
    for (var i = 0; i < devices.length; ++i)
      if (devices[i].type === DeviceType.Wifi && devices[i].connected) return devices[i]
    return null
  }
  readonly property var network: {
    var networks = wifi && wifi.networks ? wifi.networks.values : []
    for (var i = 0; i < networks.length; ++i)
      if (networks[i].connected) return networks[i]
    return null
  }
  readonly property bool wired: {
    for (var i = 0; i < devices.length; ++i)
      if (devices[i].type === DeviceType.Wired && devices[i].connected) return true
    return false
  }
  readonly property int signalBars: wired ? 4 : (network ? Math.max(1, Math.ceil(network.signalStrength * 4)) : 0)
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: battery && battery.isPresent
  readonly property int batteryPercent: hasBattery ? Math.round(battery.percentage * 100) : 0
  readonly property color batteryColor: charging ? batteryPalette.charging : (batteryPercent <= ShellConfig.batteryCriticalThreshold ? batteryPalette.critical : (batteryPercent <= ShellConfig.batteryLowThreshold ? batteryPalette.warning : root.foreground))
  readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
  readonly property var audioSink: Pipewire.defaultAudioSink
  readonly property bool muted: !audioSink || !audioSink.audio || audioSink.audio.muted
  readonly property int volumePercent: audioSink && audioSink.audio ? Math.round(audioSink.audio.volume * 100) : 0

  BatteryPalette { id: batteryPalette }

  PwObjectTracker { objects: root.audioSink ? [root.audioSink] : [] }
  SystemClock { id: clock; precision: root.hoverTarget === "clock" ? SystemClock.Seconds : SystemClock.Minutes }
  Process { id: volumeAction }
  function changeVolume(step) {
    if (!volumeAction.running)
      volumeAction.exec(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", step > 0 ? "5%+" : "5%-"])
  }

  readonly property real statusGroupWidth: 2 * ShellConfig.notchStatusSlotWidth + ShellConfig.notchStatusGap

  Row {
    id: leftStatus
    anchors.right: clockPlate.left
    anchors.rightMargin: ShellConfig.notchClockGap
    anchors.verticalCenter: parent.verticalCenter
    spacing: ShellConfig.notchStatusGap
    Item {
      width: ShellConfig.notchStatusSlotWidth
      height: root.height
      Row {
        anchors.centerIn: parent
        height: ShellConfig.notchNetworkHeight
        spacing: ShellConfig.notchNetworkBarGap
        Repeater {
          model: 4
          Rectangle {
            required property int index
            width: ShellConfig.notchNetworkBarWidth
            height: Math.max(1, ShellConfig.notchNetworkHeight * (index + 1) / 4)
            anchors.bottom: parent.bottom
            radius: 1
            color: root.foreground
            opacity: index < root.signalBars ? 1 : 0.22
          }
        }
      }
      MouseArea {
        anchors.fill: parent; anchors.margins: -2
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: root.hoverTarget = "network"
        onExited: if (root.hoverTarget === "network") root.hoverTarget = ""
        onClicked: root.openMenu("omarchy.network")
      }
    }
    Item {
      width: ShellConfig.notchStatusSlotWidth
      height: root.height
      visible: root.hasBattery
      Item {
        anchors.centerIn: parent
        width: ShellConfig.notchBatteryWidth; height: ShellConfig.notchBatteryHeight
      Rectangle {
        width: parent.width - 3; height: parent.height
        radius: Math.min(4, height / 3)
        color: "transparent"
        border.width: 1; border.color: root.foreground
        Rectangle {
          x: 2; y: 2; height: Math.max(0, parent.height - 4)
          width: Math.max(0, (parent.width - 4) * Math.min(100, root.batteryPercent) / 100)
          radius: 2
          color: root.batteryColor
        }
      }
      Rectangle {
        x: parent.width - 2; y: parent.height / 3
        width: 2; height: parent.height / 3; radius: 1
        color: root.foreground; opacity: 0.6
      }
      Canvas {
        id: chargingBolt
        visible: root.charging && ShellConfig.batteryShowChargingBolt
        x: (parent.width - 3 - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height * 0.65; height: parent.height * 0.95
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset(); ctx.clearRect(0, 0, width, height)
          ctx.scale(width / 10, height / 16)
          ctx.beginPath()
          ctx.moveTo(6, 1); ctx.lineTo(1, 9); ctx.lineTo(5, 9)
          ctx.lineTo(4, 15); ctx.lineTo(9, 6); ctx.lineTo(5, 6); ctx.closePath()
          ctx.strokeStyle = Color.background; ctx.lineWidth = 2; ctx.lineJoin = "round"
          ctx.stroke(); ctx.fillStyle = root.foreground; ctx.fill()
        }
        Connections {
          target: root
          function onForegroundChanged() { chargingBolt.requestPaint() }
        }
        Connections {
          target: Color
          function onBackgroundChanged() { chargingBolt.requestPaint() }
        }
      }
      }
      MouseArea {
        anchors.fill: parent; anchors.margins: -2
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: root.hoverTarget = "battery"
        onExited: if (root.hoverTarget === "battery") root.hoverTarget = ""
        onClicked: root.openMenu("omarchy.power")
      }
    }
  }

  Rectangle {
    id: clockPlate
    anchors.centerIn: parent
    width: Math.max(0, Math.min(ShellConfig.notchClockWidth, root.width - 2 * (root.statusGroupWidth + ShellConfig.notchClockGap)))
    height: Math.min(ShellConfig.notchClockHeight, root.height)
    radius: Math.min(ShellConfig.radius, height / 2)
    color: "#202127"
    Text {
      anchors.fill: parent
      text: Qt.formatDateTime(clock.date, "HH:mm")
      font.family: ShellConfig.notchFontFamily
      font.pixelSize: ShellConfig.notchClockFontSize; font.weight: Font.DemiBold
      fontSizeMode: Text.Fit; minimumPixelSize: Math.min(9, ShellConfig.notchClockFontSize)
      color: root.foreground
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: root.hoverTarget = "clock"
      onExited: if (root.hoverTarget === "clock") root.hoverTarget = ""
      onClicked: { root.hoverTarget = ""; root.activeMenu = ""; root.dashboardRequested() }
    }
  }

  Row {
    id: rightStatus
    anchors.left: clockPlate.right
    anchors.leftMargin: ShellConfig.notchClockGap
    anchors.verticalCenter: parent.verticalCenter
    spacing: ShellConfig.notchStatusGap
    Item {
      width: ShellConfig.notchStatusSlotWidth; height: root.height
      Image {
        anchors.centerIn: parent
        width: ShellConfig.notchIconSize; height: ShellConfig.notchIconSize
        source: "status-icons/" + (root.muted ? "speaker-slash" : root.volumePercent === 0 ? "speaker-none" : root.volumePercent < 50 ? "speaker-low" : "speaker-high") + ".svg"
        sourceSize.width: width * 2; sourceSize.height: height * 2
        layer.enabled: true
        layer.effect: MultiEffect { colorization: 1; colorizationColor: root.foreground }
      }
      MouseArea {
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: root.hoverTarget = "volume"
        onExited: if (root.hoverTarget === "volume") root.hoverTarget = ""
        onClicked: root.openMenu("omarchy.audio")
        onWheel: function(event) { root.changeVolume(event.angleDelta.y); event.accepted = true }
      }
    }
    Item {
      width: ShellConfig.notchStatusSlotWidth; height: root.height
      Image {
        id: bellIcon
        anchors.centerIn: parent
        width: ShellConfig.notchBellIconSize; height: ShellConfig.notchBellIconSize
        source: "status-icons/" + (root.dnd ? "bell-slash" : "bell") + ".svg"
        sourceSize.width: width * 2; sourceSize.height: height * 2
        layer.enabled: true
        layer.effect: MultiEffect { colorization: 1; colorizationColor: root.foreground }
        Rectangle {
          visible: !root.dnd && root.unreadCount > 0
          anchors.top: parent.top; anchors.right: parent.right
          width: 4; height: 4; radius: 2; color: root.foreground
        }
      }
      MouseArea {
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: root.hoverTarget = "notifications"
        onExited: if (root.hoverTarget === "notifications") root.hoverTarget = ""
        onClicked: root.openMenu("notifications")
      }
    }
  }

  PopupWindow {
    id: statusTooltip
    visible: root.visible && root.tooltipText !== "" && root.hostWindow !== null
    color: "transparent"
    implicitWidth: tooltipLabel.implicitWidth + 20
    implicitHeight: tooltipLabel.implicitHeight + 12
    anchor {
      window: root.hostWindow
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1; rect.height: 1
      rect.x: root.hostWindow ? Math.round(root.hostWindow.contentItem.mapFromItem(root, root.width / 2 - statusTooltip.implicitWidth / 2, root.height + 6).x) : 0
      rect.y: root.hostWindow ? Math.round(root.hostWindow.contentItem.mapFromItem(root, 0, root.height + 6).y) : 0
    }
    Rectangle {
      anchors.fill: parent
      color: "#202127"
      radius: Math.min(ShellConfig.radius, 8)
      border.width: 1; border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25)
      Text {
        id: tooltipLabel
        anchors.centerIn: parent
        text: root.tooltipText
        font.family: ShellConfig.notchFontFamily
        font.pixelSize: ShellConfig.notchTooltipFontSize
        color: root.foreground
      }
    }
  }

  NotchMenu {
    hostWindow: root.hostWindow
    foreground: root.foreground
    menuType: root.activeMenu
    notificationHistory: root.notificationHistory
    dnd: root.dnd
    onCloseRequested: root.activeMenu = ""
    onDndToggleRequested: root.dndToggleRequested()
  }

}
