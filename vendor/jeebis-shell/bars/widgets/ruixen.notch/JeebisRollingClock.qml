// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
Item {
  id: clock
  property string text: "00:00"
  property font font: Qt.font({family: "monospace", pixelSize: 15, weight: Font.DemiBold})
  property color color: "white"
  property bool animateChanges: true
  property int baseDuration: 420
  readonly property real digitWidth: {
    var width = 0
    for (var i = 0; i < 10; ++i) width = Math.max(width, metrics.advanceWidth(String(i)))
    return Math.ceil(width)
  }
  readonly property real cellHeight: Math.ceil(metrics.height) + 2
  readonly property real naturalWidth: {
    var width = 0
    for (var i = 0; i < text.length; ++i) width += /[0-9]/.test(text.charAt(i)) ? digitWidth : Math.ceil(metrics.advanceWidth(text.charAt(i)))
    return width
  }
  implicitWidth: naturalWidth
  implicitHeight: cellHeight
  clip: true
  Accessible.role: Accessible.StaticText
  Accessible.name: text
  FontMetrics { id: metrics; font: clock.font }
  Row {
    anchors.centerIn: parent
    height: clock.cellHeight
    scale: Math.max(0, Math.min(1, clock.width / Math.max(1, implicitWidth), clock.height / Math.max(1, height)))
    Repeater {
      model: clock.text.length
      JeebisRollingDigit {
        required property int index
        value: clock.text.charAt(index)
        width: /[0-9]/.test(value) ? clock.digitWidth : Math.ceil(metrics.advanceWidth(value))
        height: clock.cellHeight
        digitFont: clock.font; color: clock.color
        animateChanges: clock.animateChanges; baseDuration: clock.baseDuration
      }
    }
  }
}
