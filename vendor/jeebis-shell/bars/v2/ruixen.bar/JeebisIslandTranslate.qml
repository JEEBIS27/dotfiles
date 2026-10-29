// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
Translate {
  required property var barRoot
  property string section: "notch"
  y: -(barRoot.notchClearance + Math.abs(barRoot.contentTopInset) + 16) * (1 - barRoot.islandProgress(section))
}
