// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import "../../../motion" as Motion
import "../../../ShellConfig.js" as ShellConfig
Item {
  id: island
  property string behavior: "off"
  property bool held: false
  property string motionGroup: "bar"
  readonly property bool activity: activityTimer.running
  readonly property bool shown: behavior === "always" || (behavior === "auto" && (held || activity || bridge.running))
  property real progress: shown ? 1 : 0
  Behavior on progress { Motion.JeebisNumberAnimation { motionGroup: island.motionGroup; motionDirection: island.shown ? "show" : "hide"; baseDuration: ShellConfig.barSlideDuration } }
  function reveal() { if (behavior === "auto") activityTimer.restart() }
  function reset() { activityTimer.stop(); bridge.stop() }
  onHeldChanged: {
    if (held) bridge.stop()
    else if (behavior === "auto") bridge.restart()
  }
  Timer { id: activityTimer; interval: Math.max(1, ShellConfig.barActivityShowDuration) }
  Timer { id: bridge; interval: ShellConfig.motionDuration(ShellConfig.barSlideDuration) + 150 }
}
