import QtQuick
import QtQuick.Shapes
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
    readonly property int activeWidth: 18
    readonly property int dotSlotWidth: 11
    readonly property int dotSpacing: 5
    readonly property real naturalWidth: workspaces.reduce((width, ws) => width + (ws.active ? activeWidth : dotSlotWidth), 0)
        + Math.max(0, workspaces.length - 1) * dotSpacing

    Row {
        id: dots
        anchors.centerIn: parent
        height: parent.height
        readonly property real scaleToFit: Math.min(1, status.width / Math.max(1, status.naturalWidth))
        spacing: status.dotSpacing * scaleToFit
        Repeater {
            model: ScriptModel { values: status.workspaces.map(ws => ws.id) }
            delegate: Item {
                id: indicator
                required property string modelData
                readonly property var workspace: status.workspaces.find(ws => ws.id === modelData) || {}
                width: (workspace.active ? status.activeWidth : status.dotSlotWidth) * dots.scaleToFit
                height: dots.height
                Behavior on width { NumberAnimation { duration: StyleTokens.durationFast } }

                Rectangle {
                    anchors.centerIn: parent
                    visible: !indicator.workspace.busy || indicator.workspace.active
                    width: indicator.workspace.active ? parent.width : 7 * dots.scaleToFit
                    height: indicator.workspace.active && indicator.workspace.busy ? 14 : 7
                    radius: height / 2
                    color: indicator.workspace.active ? StyleTokens.accent : StyleTokens.textSecondary
                }
                Shape {
                    id: spinner
                    anchors.centerIn: parent
                    width: 11
                    height: width
                    scale: dots.scaleToFit
                    visible: !!indicator.workspace.busy
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: indicator.workspace.active ? StyleTokens.panel : StyleTokens.accent
                        strokeWidth: 1.5
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 5.5; centerY: 5.5
                            radiusX: 4; radiusY: 4
                            startAngle: 0; sweepAngle: 270
                        }
                    }
                    RotationAnimator on rotation {
                        running: spinner.visible && status.opacity > 0
                        from: 0; to: 360
                        duration: 650
                        loops: Animation.Infinite
                    }
                }
            }
        }
    }
}
