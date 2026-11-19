"""Morph Tide's capsule in place and gate Escape on panel entry."""
from pathlib import Path
import sys


path = Path(sys.argv[1]) / "DynamicIslandWindow.qml"
source = path.read_text()


def replace(before, after):
    global source
    if source.count(before) != 1:
        raise RuntimeError(f"upstream {path.name} changed: {before!r}")
    source = source.replace(before, after)


replace(
    '''    Behavior on autoHideProgress {
        NumberAnimation {
            duration: root.autoHideTargetVisible ? 120 : 300
            easing.type: root.autoHideTargetVisible ? Easing.OutCubic : Easing.InCubic
        }
    }''',
    '''    Behavior on autoHideProgress {
        NumberAnimation {
            id: capsuleRevealAnimation
            duration: root.autoHideTargetVisible ? 260 : 210
            easing.type: root.autoHideTargetVisible ? Easing.OutQuint : Easing.InCubic
        }
    }

    readonly property bool escapeTargetVisible: dismissibleMenu || overviewVisible
        || connectivityPromptActive || islandContainer.expandedLayerVisible
        || islandContainer.islandState === "split" || islandContainer.islandState === "long_capsule"
        || islandContainer.notificationLayerVisible || islandPeekTimer.running
    readonly property string escapePresentation: [
        islandContainer.islandState, root.overviewPhase,
        !!(controlCenterLoader.item && controlCenterLoader.item.powerViewActive),
        root.connectivityPromptActive, root.anyConnectivityDetailMounted
    ].join(":")

    onEscapeTargetVisibleChanged: {
        if (escapeTargetVisible)
            escapeEntryTimer.restart();
    }
    onEscapePresentationChanged: {
        if (escapeTargetVisible)
            escapeEntryTimer.restart();
    }

    Timer {
        id: escapeEntryTimer
        interval: Math.max(mainCapsule.morphDuration, root.connectivityDetailAnimationDuration)
    }''',
)

replace(
    "            id: mainCapsule",
    '''            id: mainCapsule

            Shortcut {
                sequence: "Escape"
                enabled: root.escapeTargetVisible
                autoRepeat: false
                onActivated: {
                    // Consume Escape during entry before child key handlers.
                    if (escapeEntryTimer.running || capsuleRevealAnimation.running
                            || capsuleWidthAnimation.running || capsuleHeightAnimation.running
                            || root.autoHideProgress < 0.999
                            || (root.overviewVisible && !root.overviewContentVisible))
                        return;
                    if (root.overviewVisible)
                        root.closeOverviewEverywhere();
                    else if (islandPeekTimer.running && !root.dismissibleMenu && root.autoHideRestingState)
                        islandPeekTimer.stop();
                    else
                        islandContainer.smartRestoreState();
                }
            }''',
)

replace(
    '''            y: userConfig.islandTopMargin
                - (1 - root.autoHideProgress) * (targetHeight + userConfig.islandTopMargin + 8)''',
    '''            // Keep the top edge fixed and grow out from a small capsule.
            readonly property real revealWidthScale: 1 - (1 - Math.min(1, 34 / Math.max(1, width)))
                * (1 - root.autoHideProgress)
            readonly property real revealHeightScale: 1 - (1 - Math.min(1, 16 / Math.max(1, height)))
                * (1 - root.autoHideProgress)
            y: userConfig.islandTopMargin''',
)

replace(
    '''            scale: 0.96 + root.autoHideProgress * 0.04
            transformOrigin: Item.Top''',
    '''            transform: Scale {
                origin.x: mainCapsule.width / 2
                origin.y: 0
                xScale: mainCapsule.revealWidthScale
                yScale: mainCapsule.revealHeightScale
            }''',
)

replace(
    '''            x: Math.floor(mainCapsule.x)
            y: Math.floor(mainCapsule.y)
            width: Math.ceil(mainCapsule.width)
            height: Math.ceil(mainCapsule.height)''',
    '''            x: Math.floor(mainCapsule.x + mainCapsule.width * (1 - mainCapsule.revealWidthScale) / 2)
            y: Math.floor(mainCapsule.y)
            width: root.autoHideProgress > 0.01 ? Math.ceil(mainCapsule.width * mainCapsule.revealWidthScale) : 0
            height: root.autoHideProgress > 0.01 ? Math.ceil(mainCapsule.height * mainCapsule.revealHeightScale) : 0''',
)

replace(
    '''            Behavior on displayedWidth  {
                NumberAnimation {''',
    '''            Behavior on displayedWidth  {
                NumberAnimation {
                    id: capsuleWidthAnimation''',
)
replace(
    '''            Behavior on height {
                enabled: !(controlCenterLoader.item && controlCenterLoader.item.batteryDrawerMoving)

                NumberAnimation {''',
    '''            Behavior on height {
                enabled: !(controlCenterLoader.item && controlCenterLoader.item.batteryDrawerMoving)

                NumberAnimation {
                    id: capsuleHeightAnimation''',
)

path.write_text(source)
