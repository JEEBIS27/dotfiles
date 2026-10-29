// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick

Scale {
  property bool independent: false
  property real progress: 1
  property real centerX: 0
  // Keep the screen-edge attachment fixed even when OutBack exceeds 1.
  origin.x: centerX
  origin.y: 0
  xScale: independent ? Math.max(0, progress) : 1
  yScale: xScale
}
