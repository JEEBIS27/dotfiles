// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import "JeebisBarVisibilityModel.js" as Model
import "JeebisBarTriggerModel.js" as Triggers
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../../ShellConfig.js" as ShellConfig
Item {
  id: control
  property var mode: ({target: "bar", behavior: "always", reserve: true})
  property var triggerSections: ({})
  property var geometryByScreen: ({})
  property bool modeLoaded: false
  property bool ready: false
  property bool hovered: false
  property bool leftHeld: false
  property bool rightHeld: false
  property bool notchHeld: false
  property bool edgeNotchHeld: false
  readonly property real notchProgress: notchIsland.progress
  readonly property bool autoHide: mode.behavior === "auto" || (!unified && mode.behavior === "always")
  readonly property bool held: hovered || leftHeld || rightHeld || notchHeld || edgeNotchHeld
  readonly property bool unified: mode.target === "bar"
  readonly property bool leftShown: modeLoaded && leftIsland.shown
  readonly property bool rightShown: modeLoaded && rightIsland.shown
  readonly property bool shown: modeLoaded && notchIsland.shown
  readonly property bool barShown: leftShown || rightShown
  readonly property real leftProgress: leftIsland.progress
  readonly property real rightProgress: rightIsland.progress
  readonly property real barProgress: Math.max(leftProgress, rightProgress)
  readonly property bool reserveSpace: modeLoaded && mode.behavior === "always" && mode.reserve
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/jeebis-shell"
  JeebisIslandVisibility { id: leftIsland; behavior: control.modeLoaded ? Model.sectionBehavior(control.mode, "left") : "off"; held: control.unified ? control.held : control.leftHeld }
  JeebisIslandVisibility { id: notchIsland; motionGroup: control.unified ? "bar" : "notch"; behavior: control.modeLoaded ? Model.sectionBehavior(control.mode, "notch") : "off"; held: control.unified ? control.held : (control.notchHeld || control.edgeNotchHeld) }
  JeebisIslandVisibility { id: rightIsland; behavior: control.modeLoaded ? Model.sectionBehavior(control.mode, "right") : "off"; held: control.unified ? control.held : control.rightHeld }
  function activityEvent(name) { triggerEvent(Triggers.eventTrigger(name)) }
  function triggerEvent(name) {
    if (!autoHide || !Triggers.enabled(ShellConfig.barTriggerModes, name, mode.target)) return
    var sections = Model.revealSections(mode.target, ShellConfig.barTriggerIslandOnly, triggerSections[name] || "notch")
    for (var i = 0; i < sections.length; ++i) {
      if (sections[i] === "left") leftIsland.reveal()
      else if (sections[i] === "right") rightIsland.reveal()
      else notchIsland.reveal()
    }
  }
  JeebisBarTriggers { onTriggered: function(name) { control.triggerEvent(name) } }
  function selectMode(target, fixed) {
    modeLoaded = true
    mode = Model.next(mode, target, fixed)
    leftIsland.reset(); notchIsland.reset(); rightIsland.reset()
  }
  onModeChanged: { if (ready && modeLoaded) saveMode(); publish() }
  onShownChanged: publish()
  onLeftShownChanged: publish()
  onRightShownChanged: publish()
  onReserveSpaceChanged: publish()
  function saveMode() { modeFile.setText(JSON.stringify({version: 3, target: mode.target, behavior: mode.behavior, reserve: mode.reserve}) + "\n") }
  function loadMode(raw) {
    if (modeLoaded) return
    try { mode = Model.normalize(JSON.parse(raw)) }
    catch (error) { mode = {target: "bar", behavior: "always", reserve: true} }
    modeLoaded = true
    if (ready) { saveMode(); publish() }
  }
  function publish() {
    if (ready && modeLoaded) stateFile.setText(JSON.stringify({version: 3, target: mode.target, behavior: mode.behavior,
      reserve: reserveSpace, leftShown: leftShown, rightShown: rightShown, barShown: barShown, notchShown: shown, autoHide: autoHide}) + "\n")
  }
  Connections { target: Hyprland; function onRawEvent(event) { control.activityEvent(event.name) } }
  FileView { id: stateFile; path: control.stateDir + "/bar-visibility.json"; atomicWrites: true; printErrors: false }
  FileView {
    id: modeFile; path: control.stateDir + "/bar-mode.json"; atomicWrites: true; printErrors: false
    onLoaded: control.loadMode(text())
    onLoadFailed: control.loadMode("")
  }
  Process {
    running: true; command: ["mkdir", "-p", control.stateDir]
    onExited: function(code) { control.ready = code === 0; if (control.ready && control.modeLoaded) { control.saveMode(); control.publish() } }
  }
  IpcHandler {
    target: "jeebis.bar"
    function toggle(): void { control.selectMode("bar", false) }
    function toggleIslands(): void { control.selectMode("islands", false) }
    function toggleFixedBar(): void { control.selectMode("bar", true) }
    function toggleFixedIslands(): void { control.selectMode("islands", true) }
    // Keep existing Hyprland bindings working without a compositor reload.
    function toggleNotch(): void { control.selectMode("islands", false) }
    function toggleFixedNotch(): void { control.selectMode("islands", true) }
    function holdNotch(held: bool): void { control.notchHeld = held }
    function trigger(name: string): void { control.triggerEvent(name) }
    function geometry(): string { return JSON.stringify(control.geometryByScreen) }
    function state(): string { return JSON.stringify({target: control.mode.target, behavior: control.mode.behavior, reserve: control.reserveSpace,
      unified: control.unified, leftShown: control.leftShown, rightShown: control.rightShown, barShown: control.barShown, notchShown: control.shown,
      activity: leftIsland.activity || notchIsland.activity || rightIsland.activity, held: control.held,
      leftProgress: control.leftProgress, rightProgress: control.rightProgress, barProgress: control.barProgress}) }
  }
}
