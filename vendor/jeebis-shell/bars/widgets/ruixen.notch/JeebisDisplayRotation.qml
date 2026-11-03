// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import Quickshell.Io
import "../../../ShellConfig.js" as ShellConfig
Item {
  id: controller
  property var state: ({available: false, transform: 0, automatic: false, sensorAvailable: false, error: ""})
  readonly property bool busy: action.running || transitionWindow.applying || transitionWindow.phase !== "idle"
  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("JeebisDisplayRotation.py").toString().replace(/^file:\/\//, ""))
  readonly property string settings: JSON.stringify({
    output: ShellConfig.displayRotationOutput, automatic: ShellConfig.displayAutoRotate,
    sensor: ShellConfig.displayRotationSensor, normalYSign: ShellConfig.displayRotationNormalYSign,
    animation: ShellConfig.displayRotationAnimationEnabled, animationDuration: ShellConfig.displayRotationAnimationDuration,
    animationSpeed: ShellConfig.motionSpeed(), delayMs: ShellConfig.displayRotationStableMs, touchDevices: ShellConfig.displayRotationTouchDevices
  })
  function receive(line) {
    try { state = JSON.parse(line) } catch (error) { console.warn("Display rotation:", error) }
  }
  function request(command) {
    if (action.running) return
    action.command = ["/usr/bin/python3", helper, command, "--config", settings]
    action.running = true
  }
  JeebisRotationTransition { id: transitionWindow }
  IpcHandler {
    target: "jeebis.display"
    function prepareRotation(output: string, angle: int, token: string): void { transitionWindow.begin(output, angle, token) }
    function applyRotation(token: string, command: string): bool { return transitionWindow.execute(token, command) }
    function completeRotation(token: string): void { transitionWindow.complete(token) }
    function abortRotation(token: string): void { transitionWindow.abort(token) }
    function rotationTransition(): string { return JSON.stringify({token: transitionWindow.token, phase: transitionWindow.phase, hasFrame: transitionWindow.hasFrame, progress: transitionWindow.progress, fade: transitionWindow.fade, remapped: transitionWindow.remapped, remapSource: transitionWindow.remapSource, orientation: transitionWindow.targetScreen ? transitionWindow.targetScreen.orientation : 0}) }
    function toggle(): void { controller.request("toggle") }
    function toggleAuto(): void { controller.request("toggle-auto") }
    function state(): string { return JSON.stringify(controller.state) }
  }
  Process {
    id: watcher
    command: ["/usr/bin/python3", controller.helper, "watch", "--config", controller.settings]
    running: true
    stdout: SplitParser { onRead: data => controller.receive(data) }
    onExited: restart.restart()
  }
  Timer { id: restart; interval: 3000; onTriggered: watcher.running = true }
  Process {
    id: action
    stdout: SplitParser { onRead: data => controller.receive(data) }
  }
}
