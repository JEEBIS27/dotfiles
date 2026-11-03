// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
Item {
  property real progress: 0
  property int turn: 180
  property real orientationOffset: 0
  readonly property real angle: turn * progress + orientationOffset
  readonly property real radians: angle * Math.PI / 180
  readonly property real boundsWidth: Math.abs(Math.cos(radians)) * width + Math.abs(Math.sin(radians)) * height
  readonly property real boundsHeight: Math.abs(Math.sin(radians)) * width + Math.abs(Math.cos(radians)) * height
  transformOrigin: Item.Center
  rotation: angle
  scale: Math.min(1, width / Math.max(1, boundsWidth), height / Math.max(1, boundsHeight))
}
