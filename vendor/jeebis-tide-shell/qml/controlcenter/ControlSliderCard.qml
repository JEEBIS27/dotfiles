import QtQuick
import IslandBackend
import "../common"

Rectangle {
    id: root

    signal interactionStarted()
    signal valueMoved(real value)
    signal commitRequested()
    signal cancelRequested()

    property string title: ""
    property string levelKind: ""
    property string textFontFamily: ""
    property real value: 0
    property real knobSize: 24
    property color moduleColor: StyleTokens.module
    property color moduleHover: StyleTokens.moduleHover
    property color trackColor: StyleTokens.track
    property color textPrimary: StyleTokens.textPrimary
    property color textSecondary: StyleTokens.textSecondary
    readonly property bool pressed: sliderArea.pressed

    function clamp01(nextValue) {
        return Math.max(0, Math.min(1, nextValue));
    }

    radius: StyleTokens.radiusModule
    color: StyleTokens.clearBlack
    clip: true

    MatteSurface {
        anchors.fill: parent
        radius: root.radius
        hovered: sliderArea.containsMouse
        pressed: sliderArea.pressed
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: root.title
            color: root.textPrimary
            font.pixelSize: 13
            font.family: root.textFontFamily
            font.weight: Font.DemiBold
        }

        Rectangle {
            id: sliderTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 24
            radius: 12
            color: "#30000000"
            readonly property real knobTravel: Math.max(0, width - root.knobSize)
            readonly property real knobX: root.clamp01(root.value) * knobTravel
            readonly property real knobRightX: knobX + root.knobSize
            border.width: 1
            border.color: StyleTokens.surfaceHighlight
            clip: true

            Rectangle {
                z: 1
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 9
                width: 18
                height: 18
                radius: 9
                color: StyleTokens.transparent

                LevelStatusIcon {
                    anchors.fill: parent
                    kind: root.levelKind
                    value: root.value
                }
            }

            Rectangle {
                // Continue underneath the entire knob. Ending at its
                // center exposes the fill's rounded cap and creates a visible
                // neck immediately before the circular handle.
                width: root.value <= 0.001 ? 0 : sliderTrack.knobRightX
                height: parent.height
                radius: parent.radius
                color: "#e6e6eb"
            }

            Rectangle {
                z: 2
                x: sliderTrack.knobX - 1
                y: (parent.height - height) / 2 + 1
                width: root.knobSize + 2
                height: root.knobSize + 1
                radius: height / 2
                color: "#20000000"
            }

            Rectangle {
                z: 3
                x: sliderTrack.knobX
                y: (parent.height - height) / 2
                width: root.knobSize
                height: root.knobSize
                radius: root.knobSize / 2
                border.width: 1
                border.color: "#929298"
                color: "#f4f5f7"
            }

            MouseArea {
                id: sliderArea
                anchors.fill: parent
                hoverEnabled: true

                function update(mouseX) {
                    if (sliderTrack.knobTravel <= 0) return;
                    root.valueMoved(root.clamp01(
                        (mouseX - root.knobSize / 2) / sliderTrack.knobTravel));
                }

                onPressed: function(mouse) {
                    root.interactionStarted();
                    update(mouse.x);
                }
                onPositionChanged: function(mouse) {
                    if (pressed)
                        update(mouse.x);
                }
                onReleased: root.commitRequested()
                onCanceled: root.cancelRequested()
            }
        }
    }
}
