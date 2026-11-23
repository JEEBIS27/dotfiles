import QtQuick

ShaderEffect {
    id: liquid
    required property Item main
    property real satelliteY: main.y + main.height / 2
    required property real satelliteX
    required property real satelliteWidth
    required property real satelliteHeight
    required property real stroke
    required property color fillTint
    required property color edgeTint
    readonly property real padding: stroke + 3
    x: Math.min(main.x, satelliteX - satelliteWidth / 2) - padding
    y: Math.min(main.y, satelliteY - satelliteHeight / 2) - padding
    width: Math.max(main.x + main.width, satelliteX + satelliteWidth / 2) - x + padding
    height: Math.max(main.y + main.height, satelliteY + satelliteHeight / 2) - y + padding
    readonly property vector2d canvasSize: Qt.vector2d(width, height)
    readonly property vector4d body: Qt.vector4d(main.x + main.width / 2 - x, main.y + main.height / 2 - y, main.width, main.height)
    readonly property vector4d satellite: Qt.vector4d(satelliteX - x, satelliteY - y, satelliteWidth, satelliteHeight)
    readonly property real bodyRadius: main.radius
    readonly property real tension: Math.max(1, Math.min(main.height, satelliteHeight) * 0.48)
    fragmentShader: Qt.resolvedUrl("liquid.frag.qsb")
}
