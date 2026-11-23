import QtQuick
import Quickshell
import IslandBackend

Item {
    id: status
    required property string outputName

    readonly property var workspaces: {
        CompositorBackend.revision;
        return Array.from(CompositorBackend.workspaceIndicators(outputName))
            .filter(workspace => workspace.active || workspace.occupied);
    }
    Row {
        id: dots
        anchors.centerIn: parent
        height: parent.height
        readonly property real scaleToFit: Math.min(1, status.width / Math.max(1, 12 * status.workspaces.length + 11))
        spacing: 5 * scaleToFit
        Repeater {
            model: ScriptModel { values: status.workspaces.map(ws => ws.id) }
            delegate: Item {
                id: indicator
                required property string modelData
                readonly property var workspace: status.workspaces.find(ws => ws.id === modelData) || {}
                width: (workspace.active ? 18 : 7) * dots.scaleToFit
                height: dots.height
                Behavior on width { NumberAnimation { duration: StyleTokens.durationFast } }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 7
                    radius: height / 2
                    color: indicator.workspace.active ? StyleTokens.accent : StyleTokens.textSecondary
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.verticalCenter
                    anchors.bottomMargin: 5
                    width: 3
                    height: 3
                    radius: 2
                    color: StyleTokens.accent
                    visible: !!indicator.workspace.busy
                    SequentialAnimation on opacity {
                        running: !!indicator.workspace.busy
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.3; duration: 500 }
                        NumberAnimation { from: 0.3; to: 1; duration: 500 }
                    }
                }
            }
        }
    }

}
