// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import "../../../motion" as Motion
Item {
  id: digit
  property string value: ""
  property font digitFont: Qt.font({family: "monospace", pixelSize: 15})
  property color color: "white"
  property int baseDuration: 420
  property bool animateChanges: true
  property string previous: ""
  property string current: ""
  property real progress: 1
  property bool initialized: false
  readonly property bool rolling: roll.running
  clip: true
  function settle() {
    roll.stop()
    previous = value; current = value; progress = 1
  }
  function update() {
    if (!initialized || value === current) return
    var origin = roll.running && progress < 0.5 ? previous : current
    roll.stop()
    previous = origin; current = value
    if (!animateChanges || !/^[0-9]$/.test(origin) || !/^[0-9]$/.test(value)) { settle(); return }
    progress = 0
    roll.start()
  }
  onValueChanged: update()
  onAnimateChangesChanged: if (!animateChanges && initialized) settle()
  Component.onCompleted: { settle(); initialized = true }
  Motion.JeebisNumberAnimation { motionGroup: "notch";
    id: roll
    target: digit; property: "progress"; from: 0; to: 1
    baseDuration: digit.baseDuration
  }
  Text {
    id: outgoing
    width: parent.width; height: parent.height
    y: -height * digit.progress
    text: digit.previous; font: digit.digitFont; color: digit.color
    opacity: Math.max(0, Math.min(1, 1 - digit.progress))
    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    Accessible.ignored: true
    transform: Rotation {
      origin.x: outgoing.width / 2; origin.y: outgoing.height / 2
      axis.x: 1; axis.y: 0; axis.z: 0
      angle: -70 * digit.progress
    }
  }
  Text {
    id: incoming
    width: parent.width; height: parent.height
    y: height * (1 - digit.progress)
    text: digit.current; font: digit.digitFont; color: digit.color
    opacity: Math.max(0, Math.min(1, digit.progress))
    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    Accessible.ignored: true
    transform: Rotation {
      origin.x: incoming.width / 2; origin.y: incoming.height / 2
      axis.x: 1; axis.y: 0; axis.z: 0
      angle: 70 * (1 - digit.progress)
    }
  }
}
