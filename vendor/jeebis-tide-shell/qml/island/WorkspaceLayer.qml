import QtQuick
import Quickshell
import IslandBackend
import "../workspace"

Item {
    id: root

    readonly property var userConfig: UserConfig

    property int workspaceId: 1
    property string displayText: "Workspace " + workspaceId
    property string outputName: ""
    property string appId: ""
    property bool appOpened: false
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string textFontFamily: activeConfig.textFontFamily
    property bool showCondition: false
    property int textPixelSize: userConfig.bodyFontSize
    property string slideDirection: "none"
    property bool animateVisibility: true
    property real transitionProgress: 0
    property real horizontalPadding: 14
    property real hiddenLeftPadding: 16
    property real hiddenRightPadding: 16

    readonly property real clampedProgress: slideDirection === "right"
        ? Math.max(0, Math.min(1, transitionProgress))
        : (slideDirection === "left"
            ? Math.max(0, Math.min(1, -transitionProgress))
            : 0)
    readonly property real revealProgress: slideDirection === "none" ? 1 : (1 - clampedProgress)
    readonly property bool showsWorkspaceDots: outputName !== "" && appId === ""
    readonly property real preferredWidth: showsWorkspaceDots && workspaceStatus.naturalWidth > 0
        ? workspaceStatus.naturalWidth + horizontalPadding * 2 : 220

    readonly property real textWidth: Math.max(0, width - horizontalPadding * 2)
    readonly property real centeredX: horizontalPadding
    readonly property real hiddenLeftX: -textWidth - hiddenLeftPadding
    readonly property real hiddenRightX: width + hiddenRightPadding
    readonly property real labelX: slideDirection === "right"
        ? centeredX + (hiddenRightX - centeredX) * clampedProgress
        : (slideDirection === "left"
            ? centeredX + (hiddenLeftX - centeredX) * clampedProgress
            : centeredX)

    anchors.fill: parent
    clip: true
    opacity: showCondition ? (animateVisibility ? revealProgress : 1) : 0

    Behavior on opacity {
        enabled: animateVisibility

        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        visible: root.outputName === "" && root.appId === ""
        x: labelX
        width: textWidth
        anchors.verticalCenter: parent.verticalCenter
        text: displayText
        color: "white"
        opacity: revealProgress
        font.pixelSize: textPixelSize
        font.family: textFontFamily
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    WorkspaceStatus {
        id: workspaceStatus
        visible: root.showsWorkspaceDots
        outputName: root.outputName
        x: root.labelX
        width: root.textWidth
        height: root.height
        opacity: root.revealProgress
    }

    Loader {
        active: root.appId !== ""
        x: root.labelX
        width: root.textWidth
        height: root.height
        opacity: root.revealProgress
        sourceComponent: Item {
            id: activity
            readonly property var entry: DesktopEntries.heuristicLookup(root.appId)
            readonly property string eventKey: root.appId + ":" + root.appOpened
            onEventKeyChanged: iconMotion?.restart()
            Component.onCompleted: iconMotion.restart()

            Row {
                anchors.centerIn: parent
                spacing: 7
                Image {
                    id: appIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17
                    height: 17
                    source: Quickshell.iconPath(activity.entry?.icon || root.appId, "application-x-executable")
                    ParallelAnimation {
                        id: iconMotion
                        NumberAnimation {
                            target: appIcon; property: "scale"
                            from: root.appOpened ? 0.6 : 1
                            to: root.appOpened ? 1 : 0.65
                            duration: 220; easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: appIcon; property: "opacity"
                            from: root.appOpened ? 0 : 1
                            to: root.appOpened ? 1 : 0.45
                            duration: 220
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, Math.max(0, activity.width - 25))
                    text: root.appOpened ? qsTr("%1 opened").arg(activity.entry?.name || root.appId)
                                         : qsTr("%1 closed").arg(activity.entry?.name || root.appId)
                    color: StyleTokens.textPrimary
                    font.pixelSize: root.textPixelSize
                    font.family: root.textFontFamily
                    elide: Text.ElideRight
                }
            }
        }
    }
}
