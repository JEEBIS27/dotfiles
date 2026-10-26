// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
pragma ComponentBehavior: Bound
import "../../../ShellConfig.js" as ShellConfig
import "JeebisCalendarModel.js" as CalendarModel
import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

PopupCard {
  id: root
  property date today: CalendarModel.currentDate()
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()
  readonly property var days: CalendarModel.monthGrid(viewYear, viewMonth, today)
  contentWidth: 308
  contentHeight: 324
  padding: 12
  margin: ShellConfig.barBottomGap + 4
  function resetToToday() {
    viewYear = today.getFullYear()
    viewMonth = today.getMonth()
  }
  function stepMonth(offset) {
    var next = CalendarModel.monthAt(viewYear, viewMonth, offset)
    viewYear = next.year
    viewMonth = next.month
  }
  onOpenChanged: if (open) Qt.callLater(function() { body.forceActiveFocus() })
  Column {
    id: body
    anchors.fill: parent
    spacing: 8
    focus: true
    Keys.onEscapePressed: root.close()
    Keys.onLeftPressed: root.stepMonth(-1)
    Keys.onRightPressed: root.stepMonth(1)
    Row {
      width: parent.width
      height: 32
      Repeater {
        model: ["‹", Qt.formatDate(CalendarModel.monthDate(root.viewYear, root.viewMonth), "yyyy年 M月"), "›"]
        Rectangle {
          id: monthButton
          required property int index
          required property string modelData
          width: index === 1 ? body.width - 64 : 32
          height: 32
          radius: Math.min(ShellConfig.radius, height / 2)
          color: monthMouse.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent"
          Text {
            anchors.centerIn: parent
            text: monthButton.modelData
            color: Color.foreground
            font.family: ShellConfig.dateFontFamily
            font.pixelSize: monthButton.index === 1 ? 14 : 22
          }
          MouseArea {
            id: monthMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: monthButton.index === 1 ? root.resetToToday() : root.stepMonth(monthButton.index === 0 ? -1 : 1)
          }
        }
      }
    }
    Row {
      width: parent.width
      height: 24
      Repeater {
        model: ["月", "火", "水", "木", "金", "土", "日"]
        Text {
          required property string modelData
          width: body.width / 7
          height: 24
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: modelData
          color: Color.foreground
          opacity: 0.6
          font.family: ShellConfig.dateFontFamily
          font.pixelSize: 12
        }
      }
    }
    Grid {
      width: parent.width
      columns: 7
      Repeater {
        model: root.days
        Rectangle {
          id: dayCell
          required property var modelData
          width: body.width / 7
          height: 30
          color: "transparent"
          Rectangle {
            anchors.centerIn: parent
            width: 28; height: 28; radius: 14
            color: dayCell.modelData.today ? Color.accent : "transparent"
          }
          Text {
            anchors.centerIn: parent
            text: dayCell.modelData.day
            color: dayCell.modelData.today ? Color.background : Color.foreground
            opacity: dayCell.modelData.currentMonth ? 1 : 0.3
            font.family: ShellConfig.dateFontFamily
            font.pixelSize: 13
          }
        }
      }
    }
    Rectangle {
      width: parent.width
      height: 28
      radius: Math.min(ShellConfig.radius, height / 2)
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, todayMouse.containsMouse ? 0.12 : 0.06)
      Text {
        anchors.centerIn: parent
        text: "今日"
        color: Color.foreground
        font.family: ShellConfig.dateFontFamily
        font.pixelSize: 12
      }
      MouseArea { id: todayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.resetToToday() }
    }
  }
}
