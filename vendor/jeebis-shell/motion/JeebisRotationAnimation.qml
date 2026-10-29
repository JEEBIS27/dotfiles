// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import "../ShellConfig.js" as ShellConfig

RotationAnimation {
  property int baseDuration: 250
  property bool bounded: false
  property string motionGroup: "bar"
  property string motionDirection: ""
  readonly property string preset: ShellConfig.motionPreset(bounded, motionGroup, motionDirection)
  duration: ShellConfig.motionDuration(baseDuration)
  easing.type: preset === "Linear" ? Easing.Linear
    : preset === "OutBack" ? Easing.OutBack
    : preset === "OutBounce" ? Easing.OutBounce
    : preset === "InQuart" ? Easing.InQuart : Easing.InOutSine
  easing.overshoot: ShellConfig.motionOvershoot()
}
