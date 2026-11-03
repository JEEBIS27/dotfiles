// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../ShellConfig.js" as ShellConfig
import "../../../motion" as Motion
PanelWindow {
  id: transition
  property string phase: "idle"
  property string token: ""
  property var targetScreen: null
  property int turn: 180
  property int originalOrientation: 0
  property bool remapped: false
  property string remapSource: ""
  property real progress: 0
  property real fade: 0
  property string nativeToken: ""
  readonly property bool applying: nativeRotation.running
  readonly property bool hasFrame: frameLoader.item ? frameLoader.item.hasContent : false
  onHasFrameChanged: if (hasFrame) captured()
  screen: targetScreen
  visible: phase !== "idle"
  mask: Region { width: transition.phase === "capture" ? 0 : transition.width; height: transition.height }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "jeebis-display-rotation"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  anchors { top: true; bottom: true; left: true; right: true }
  function begin(output, angle, requestToken) {
    if (nativeRotation.running) return
    reset()
    token = requestToken
    targetScreen = Quickshell.screens.find(s => s.name === output) || null
    if (!targetScreen) return
    originalOrientation = targetScreen.orientation
    turn = angle
    phase = "capture"
    deadline.start()
  }
  function captured() {
    if (phase !== "capture" || !hasFrame) return
    phase = "rotate"
    Qt.callLater(() => { if (phase === "rotate") rotate.start() })
  }
  function compensate(source) {
    if (remapped || phase !== "ready") return
    remapped = true
    remapSource = source
  }
  function execute(requestToken, command) {
    if (requestToken !== token || phase !== "ready" || nativeRotation.running) return false
    nativeToken = requestToken
    nativeRotation.command = ["hyprctl", "eval", command]
    nativeTimeout.start()
    nativeRotation.running = true
    return true
  }
  function complete(requestToken) {
    if (requestToken !== token || phase !== "ready") return
    // Fallback for compositors that don't emit a Qt screen-orientation signal.
    compensate("acknowledge")
    phase = "crossfade"
    crossfadeMotion.start()
  }
  function abort(requestToken) { if (requestToken === token) reset() }
  function reset() {
    rotate.stop(); crossfadeMotion.stop(); deadline.stop()
    phase = "idle" // unload the single captured frame and release its buffers
    progress = 0; fade = 0; remapped = false; remapSource = ""; targetScreen = null
  }
  Component.onDestruction: reset()
  Connections {
    target: transition.targetScreen
    function onOrientationChanged() {
      if (transition.targetScreen.orientation !== transition.originalOrientation)
        transition.compensate("orientation")
    }
  }
  Process {
    id: nativeRotation
    onExited: code => {
      nativeTimeout.stop()
      if (transition.nativeToken !== transition.token || transition.phase !== "ready") return
      if (code === 0) {
        // Compensate in this GUI turn, without a Python poll + return IPC delay.
        transition.compensate("native-process")
        transition.complete(transition.nativeToken)
      } else transition.abort(transition.nativeToken)
    }
  }
  Timer {
    id: nativeTimeout
    interval: 3000
    onTriggered: {
      nativeRotation.running = false
      transition.abort(transition.nativeToken)
    }
  }
  Timer {
    id: deadline
    interval: ShellConfig.motionDuration(ShellConfig.displayRotationAnimationDuration) + 5000
    onTriggered: transition.reset()
  }
  // Matte only fills the corners while the old frame is turning. It is never
  // faded in at the end; native output rotation is hidden by the captured frame.
  Rectangle {
    anchors.fill: parent
    color: "black"
    visible: (transition.phase === "rotate" || transition.phase === "ready") && !transition.remapped
  }
  JeebisRotationVisual {
    anchors.fill: parent
    opacity: transition.phase === "capture" ? 0 : 1 - transition.fade
    progress: transition.progress
    turn: transition.turn
    orientationOffset: transition.remapped ? -transition.turn : 0
    Loader {
      id: frameLoader
      anchors.fill: parent
      // Retain the old frame through the dissolve, not merely through rotation.
      active: transition.phase === "capture" || transition.phase === "rotate" || transition.phase === "ready" || transition.phase === "crossfade"
      sourceComponent: ScreencopyView {
        captureSource: transition.targetScreen
        live: false
        paintCursor: false
        onStopped: if (transition.phase === "capture") transition.reset()
      }
      onLoaded: transition.captured()
    }
  }
  Motion.JeebisNumberAnimation {
    id: rotate
    motionGroup: "rotation"
    target: transition; property: "progress"; from: 0; to: 1
    baseDuration: ShellConfig.displayRotationAnimationDuration
    onFinished: if (transition.phase === "rotate") transition.phase = "ready"
  }
  Motion.JeebisNumberAnimation {
    id: crossfadeMotion
    motionGroup: "rotation"; motionDirection: "hide"; bounded: true
    target: transition; property: "fade"; from: 0; to: 1
    baseDuration: ShellConfig.displayRotationCrossfadeDuration
    onFinished: transition.reset()
  }
}
