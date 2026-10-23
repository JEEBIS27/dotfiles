import "../../../ShellConfig.js" as ShellConfig
import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "ruixen.date"
  implicitWidth: content.implicitWidth
  implicitHeight: ShellConfig.islandHeight
  readonly property color foreground: bar ? bar.foreground : Color.foreground
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
