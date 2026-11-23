import QtQuick
import IslandBackend

Item {
    id: root
    required property string iconSource
    Rectangle {
        anchors.centerIn: parent
        width: 17
        height: 14
        radius: 3
        color: "transparent"
        border.color: StyleTokens.textPrimary
        visible: icon.status !== Image.Ready
        Rectangle {
            x: 1
            y: 4
            width: parent.width - 2
            height: 1
            color: parent.border.color
        }
    }
    Image {
        id: icon
        anchors.centerIn: parent
        visible: status === Image.Ready
        width: 20
        height: width
        source: root.iconSource
    }
}
