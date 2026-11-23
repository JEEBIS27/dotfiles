import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import IslandBackend

Item {
    id: center
    required property var hub
    readonly property real contentHeight: 264
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "Notifications"; color: StyleTokens.textPrimary; font.bold: true; font.pixelSize: 17 }
            IslandButton { visible: !!center.hub && center.hub.history.length > 0; text: "Clear"; onClicked: center.hub.send({op:"clear"}) }
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 5
            model: center.hub ? center.hub.history : []
            delegate: Rectangle {
                id: card
                required property var modelData
                width: list.width; height: details.implicitHeight + 16; radius: 14; color: StyleTokens.module
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: center.hub.send({op:"open",id:card.modelData.id}) }
                Column {
                    id: details
                    x: 12; y: 8; width: parent.width - 24; spacing: 3
                    Repeater {
                        model: [card.modelData.source.app, card.modelData.title, card.modelData.body]
                        Text {
                            required property int index; required property string modelData
                            width: details.width; visible: !!text; text: modelData; wrapMode: Text.Wrap; textFormat: Text.PlainText
                            maximumLineCount: 3; elide: Text.ElideRight; font.bold: index === 1
                            color: index === 1 ? StyleTokens.textPrimary : StyleTokens.textSecondary; font.pixelSize: index === 1 ? 14 : 12
                        }
                    }
                    Flow {
                        width: parent.width; spacing: 4
                        Repeater {
                            model: (card.modelData.actions || []).filter(a => a[0] !== "default")
                            IslandButton {
                                required property var modelData; text: modelData[1]
                                onClicked: center.hub.send({op:"action",id:card.modelData.id,value:modelData[0]})
                            }
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent; visible: list.count === 0
                text: "No notifications"; color: StyleTokens.textSecondary
            }
        }
    }
}
