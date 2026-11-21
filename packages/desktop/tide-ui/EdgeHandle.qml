import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: handle
    required property bool leftEdge
    signal activated()
    anchors.left: leftEdge
    anchors.right: !leftEdge
    implicitWidth: 12
    implicitHeight: 88
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: leftEdge ? "tide-notification-handle" : "tide-control-handle"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    Rectangle {
        anchors.centerIn: parent
        width: pointer.containsMouse || pointer.pressed ? 5 : 3
        height: pointer.containsMouse || pointer.pressed ? 54 : 38
        radius: width / 2
        color: pointer.containsMouse ? "#ddffffff" : "#83969ba5"
        Behavior on height { NumberAnimation { duration: 150 } }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        property real startX: 0
        property real startY: 0
        onPressed: mouse => { startX = mouse.x; startY = mouse.y }
        onReleased: mouse => {
            const inward = (mouse.x - startX) * (handle.leftEdge ? 1 : -1)
            if (inward >= 14 || (Math.abs(inward) < 8 && Math.abs(mouse.y - startY) < 8))
                handle.activated()
        }
        Accessible.role: Accessible.Button
        Accessible.name: handle.leftEdge ? "Notification Center" : "Control Center"
        Accessible.onPressAction: handle.activated()
    }
}
