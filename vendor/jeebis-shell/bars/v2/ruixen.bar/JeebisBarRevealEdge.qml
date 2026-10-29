// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import Quickshell
import Quickshell.Wayland
import "JeebisBarVisibilityModel.js" as Model
PanelWindow {
  id: edge
  required property var barRoot
  readonly property var geometry: barRoot.islandGeometry(barRoot.screenNameForWindow(edge))
  property string hoveredSection: ""
  function point(section) {
    if (hoveredSection === section) return
    barRoot.setIslandHovered(hoveredSection, false)
    hoveredSection = section
    barRoot.setIslandHovered(hoveredSection, true)
  }
  visible: barRoot.barAutoHide
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "jeebis-bar-reveal-edge"
  WlrLayershell.layer: WlrLayer.Top
  anchors { top: true; left: true; right: true }
  // Only the very top edge may summon hidden content. A full-height
  // invisible sensor steals the underlying application's titlebar buttons.
  implicitHeight: 1
  mask: Region {
    width: edge.barRoot.islandsMode ? 0 : edge.width
    height: edge.height
    Region { x: edge.geometry.left.x; width: edge.barRoot.islandsMode ? edge.geometry.left.width : 0; height: edge.height }
    Region { x: edge.geometry.notch.x; width: edge.barRoot.islandsMode ? edge.geometry.notch.width : 0; height: edge.height }
    Region { x: edge.geometry.right.x; width: edge.barRoot.islandsMode ? edge.geometry.right.width : 0; height: edge.height }
  }
  HoverHandler {
    id: hover
    onHoveredChanged: edge.point(hovered ? (edge.barRoot.islandsMode ? Model.sectionAt(edge.geometry, point.position.x) : "notch") : "")
    readonly property real pointerX: point.position.x
    onPointerXChanged: if (hovered) edge.point(edge.barRoot.islandsMode ? Model.sectionAt(edge.geometry, pointerX) : "notch")
    Component.onDestruction: edge.point("")
  }
}
