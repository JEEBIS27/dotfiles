import QtQuick
import IslandBackend
import "../design"

Item {
    id: root

    property real radius: StyleTokens.radiusModule
    property bool hovered: false
    property bool pressed: false
    IslandSurface {
        anchors.fill: parent
        radius: Math.min(root.radius, StyleTokens.radiusModule)
        color: root.pressed ? "#10000000" : root.hovered ? "#1fffffff" : "#13ffffff"
        frameWidth: 1
        frameColor: root.hovered ? "#2affffff" : StyleTokens.surfaceHighlight

        Behavior on color {
            ColorAnimation { duration: StyleTokens.durationFast }
        }
    }
}
