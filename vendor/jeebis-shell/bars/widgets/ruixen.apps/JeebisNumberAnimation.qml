// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import "../../../ShellConfig.js" as ShellConfig

// Shared preset for app motion; bounded channels cannot overshoot their range.
NumberAnimation {
  property bool bounded: false
  readonly property string preset: ShellConfig.motionPreset(bounded)
  easing.type: preset === "linear" ? Easing.Linear
    : preset === "overshoot" ? Easing.OutBack : Easing.InOutSine
  easing.overshoot: ShellConfig.motionOvershoot()
}
