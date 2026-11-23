import QtQuick
import QtQuick.Shapes

Shape {
    id: frame

    property real strokeWidth: 4
    property real surfaceRadius: 15
    property real pixelRatio: Screen.devicePixelRatio
    property color strokeColor: "#26ffffff"
    property bool outset: false

    readonly property real scaleFactor: pixelRatio > 0 ? pixelRatio : 1
    readonly property real alignedWidth: strokeWidth > 0
        ? Math.max(1, Math.round(strokeWidth * scaleFactor)) / scaleFactor : 0
    readonly property real extension: outset ? alignedWidth : 0
    readonly property real inset: alignedWidth / 2

    visible: alignedWidth > 0 && width > alignedWidth && height > alignedWidth
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "transparent"
        strokeColor: frame.strokeColor
        strokeWidth: frame.alignedWidth
        PathRectangle {
            x: frame.inset
            y: frame.inset
            width: Math.max(0, frame.width - frame.alignedWidth)
            height: Math.max(0, frame.height - frame.alignedWidth)
            // Clamp the centerline radius to the path's available area.
            radius: Math.max(0, Math.min(Math.min(width, height) / 2,
                frame.surfaceRadius + frame.extension - frame.inset))
        }
    }
}
