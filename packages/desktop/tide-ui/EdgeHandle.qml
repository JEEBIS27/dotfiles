import QtQuick
import Quickshell
import Quickshell.Wayland
import IslandBackend

PanelWindow {
    id: handle
    required property bool leftEdge
    required property bool opened
    signal activated(bool wasOpen)
    anchors.top: true
    anchors.left: leftEdge
    anchors.right: !leftEdge
    margins.left: leftEdge ? 12 : 0
    margins.right: leftEdge ? 0 : 12
    implicitWidth: 56
    implicitHeight: 26
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: leftEdge ? "tide-notification-handle" : "tide-control-handle"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: -8
        radius: 12
        color: pointer.containsMouse || pointer.pressed || handle.opened ? StyleTokens.module : StyleTokens.panel
        border.color: StyleTokens.surfaceBorder
        border.width: 1

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 11
            width: 25
            height: 3
            radius: height / 2
            color: pointer.containsMouse || handle.opened ? StyleTokens.textPrimary : StyleTokens.textTertiary
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        property real startX: 0
        property real startY: 0
        property bool wasOpen: false
        onPressed: mouse => {
            startX = mouse.x
            startY = mouse.y
            wasOpen = handle.opened
        }
        onReleased: mouse => {
            const dx = mouse.x - startX
            const dy = mouse.y - startY
            if (dy >= 14 || (Math.abs(dx) < 8 && Math.abs(dy) < 8))
                handle.activated(wasOpen)
        }
        Accessible.role: Accessible.Button
        Accessible.name: handle.leftEdge ? "Notification Center" : "Control Center"
        Accessible.onPressAction: handle.activated(handle.opened)
    }
}
