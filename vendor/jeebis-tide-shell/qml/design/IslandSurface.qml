import QtQuick

Rectangle {
    id: surface

    property color tint: "#202125"
    property real materialOpacity: 1
    property real frameWidth: 4
    property color frameColor: "#26ffffff"
    property bool outsideFrame: false
    property real pixelRatio: Screen.devicePixelRatio
    readonly property real alignedFrameWidth: frame.alignedWidth

    radius: Math.min(15, width / 2, height / 2)
    color: Qt.alpha(tint, materialOpacity)
    border.width: 0
    antialiasing: true

    IslandFrame {
        id: frame
        anchors.fill: parent
        anchors.margins: -extension
        strokeWidth: surface.frameWidth
        strokeColor: surface.frameColor
        surfaceRadius: surface.radius
        outset: surface.outsideFrame
        pixelRatio: surface.pixelRatio
    }
}
