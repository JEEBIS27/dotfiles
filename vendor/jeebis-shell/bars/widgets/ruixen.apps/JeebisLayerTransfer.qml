// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Window
import qs.Commons
import "../../../ShellConfig.js" as ShellConfig

Item {
  id: proxy
  required property var coordinator
  required property var barRoot
  required property string appKey
  required property string appIcon
  required property real startX
  required property bool toFloating
  required property int serial
  property bool ready: false
  property real progress: 0
  readonly property real targetX: coordinator.transferTargetX(appKey, toFloating)
  x: startX + (targetX - startX) * progress
  width: Style.bar.iconSlot
  height: ShellConfig.islandHeight
  z: 20
  // One persistent image, full opacity from pickup through final handoff.
  function restartFlight() {
    flight.stop()
    progress = 0
    Qt.callLater(function() { flight.start() })
  }
  Component.onCompleted: { ready = true; restartFlight() }
  onSerialChanged: if (ready) restartFlight()
  JeebisNumberAnimation {
    id: flight
    target: proxy
    property: "progress"
    to: 1
    baseDuration: ShellConfig.appTransfer.movingMs
    onFinished: proxy.coordinator.finishTransfer(proxy.appKey, proxy.serial)
  }
  AppCapsule {
    barRoot: proxy.barRoot
    x: -ShellConfig.islandPadding
    width: proxy.width + 2 * ShellConfig.islandPadding
    height: proxy.height
    opacity: Math.max(0, Math.sin(Math.PI * Math.max(0, Math.min(1, proxy.progress))))
  }
  Image {
    anchors.centerIn: parent
    width: Style.bar.iconCanvas
    height: Style.bar.iconCanvas
    sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
    source: proxy.coordinator.group(proxy.toFloating).iconSource(proxy.appIcon)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
  }
}
