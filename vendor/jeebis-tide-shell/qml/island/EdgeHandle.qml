import QtQuick
import Quickshell
import Quickshell.Wayland
import IslandBackend

PanelWindow {
    id: handle
    required property bool leftEdge
    required property bool opened
    signal activated(bool wasOpen)
    property bool revealed: false
    property bool suppressed: false
    visible: !opened
    onOpenedChanged: {
        revealed = false;
        suppressed = opened;
    }
    anchors.top: true
    anchors.left: leftEdge
    anchors.right: !leftEdge
    implicitWidth: 68
    implicitHeight: 14
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: leftEdge ? "tide-notification-handle" : "tide-control-handle"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Wayland hover requires an input region. Leave only a one-pixel trigger
    // while hidden so the rest of this window passes input through.
    mask: Region {
        width: Math.ceil(pointer.width)
        height: Math.ceil(pointer.height)
    }
    Timer {
        id: dismiss
        interval: UserConfig.durations.edgeHandleDurationMs
        running: handle.revealed && !pointer.pressed
        onTriggered: handle.hideHandle()
    }
    function hideHandle() {
        suppressed = true;
        revealed = false;
    }
    Rectangle {
        readonly property real scaleFactor: handle.devicePixelRatio > 0 ? handle.devicePixelRatio : 1
        width: Math.round(25 * scaleFactor) / scaleFactor
        height: Math.round(3 * scaleFactor) / scaleFactor
        x: Math.round((parent.width - width) * scaleFactor / 2) / scaleFactor
        y: Math.round((parent.height - height) * scaleFactor / 2) / scaleFactor
        radius: height / 2
        visible: handle.revealed
        color: StyleTokens.textPrimary
    }
    MouseArea {
        id: pointer
        anchors.top: parent.top
        width: parent.width
        height: handle.revealed ? parent.height : 1
        hoverEnabled: true
        cursorShape: handle.revealed ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: {
            if (!handle.suppressed)
                handle.revealed = true;
        }
        onExited: {
            handle.revealed = false;
            handle.suppressed = false;
        }
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
            if (mouse.button === Qt.RightButton) {
                handle.hideHandle();
                return;
            }
            if (!handle.revealed)
                return;
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
