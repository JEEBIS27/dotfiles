// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import Quickshell
import Quickshell.Wayland
PanelWindow {
  required property var barRoot
  visible: barRoot.barReservesSpace
  anchors { top: true; left: true; right: true }
  implicitHeight: 1
  color: "transparent"
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: barRoot.notchClearance + barRoot.contentTopInset
  WlrLayershell.namespace: "jeebis-bar-reservation"
  WlrLayershell.layer: WlrLayer.Top
  mask: Region {}
}
