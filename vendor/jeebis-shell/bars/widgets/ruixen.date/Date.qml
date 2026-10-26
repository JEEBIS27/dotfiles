// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import "../../../ShellConfig.js" as ShellConfig
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "ruixen.date"
  implicitWidth: content.implicitWidth
  implicitHeight: ShellConfig.islandHeight
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property bool opened: calendar.open
  function open() { calendar.resetToToday(); calendar.open = true }
  function close() { singleClick.stop(); calendar.open = false }
  function toggleCalendar() { if (calendar.open) close(); else open() }
  function openGoogleCalendar() {
    close()
    var entry = DesktopEntries.byId("Calendar")
    if (entry) entry.execute()
    else Quickshell.execDetached(["xdg-open", "https://calendar.google.com/calendar"])
  }
  Timer {
    id: singleClick
    interval: Qt.styleHints.mouseDoubleClickInterval + 20
    onTriggered: root.toggleCalendar()
  }
  MouseArea {
    anchors.fill: parent
    anchors.leftMargin: -ShellConfig.dateIslandPadding
    anchors.rightMargin: -ShellConfig.dateIslandPadding
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: singleClick.restart()
    onDoubleClicked: function(mouse) {
      mouse.accepted = true
      root.openGoogleCalendar()
    }
  }
  JeebisCalendar { id: calendar; today: clock.date; anchorItem: root; bar: root.bar; owner: root }
  IpcHandler {
    target: "jeebis.date"
    function open(): void { root.broadcast("open") }
    function close(): void { root.broadcast("close") }
  }
  SystemClock { id: clock; precision: SystemClock.Minutes }
  Row {
    id: content
    anchors.centerIn: parent
    spacing: ShellConfig.dateSeparatorGap
    Text {
      text: Qt.formatDateTime(clock.date, "yy/MM/dd")
      color: root.foreground
      font.family: ShellConfig.dateFontFamily
      font.pixelSize: ShellConfig.dateFontSize
      font.weight: Font.Normal
      anchors.verticalCenter: parent.verticalCenter
    }
    Rectangle {
      width: 1; height: ShellConfig.dateSeparatorHeight
      color: root.foreground; opacity: 0.45
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][clock.date.getDay()]
      color: root.foreground
      font.family: ShellConfig.dateFontFamily
      font.pixelSize: ShellConfig.dateFontSize
      font.weight: Font.Normal
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
