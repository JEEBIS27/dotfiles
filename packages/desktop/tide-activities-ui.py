"""Integrate the activity views after the local keyboard and motion adaptations."""
from pathlib import Path
import sys


root = Path(sys.argv[1])


def edit(name, changes):
    path = root / name
    data = path.read_text()
    for before, after in changes:
        if isinstance(before, tuple):
            start, end = before
            a = data.index(start)
            b = data.index(end, a + len(start))
            data = data[:a] + after + data[b:]
        else:
            if data.count(before) != 1:
                raise ValueError(f"{name}: expected one occurrence of {before[:70]!r}")
            data = data.replace(before, after)
    path.write_text(data)


edit("shell.qml", [
    ("    property bool focusEnabled:", """    readonly property var activityHub: activities
    ActivityHub { id: activities; silent: shellRoot.focusEnabled }
    property bool focusEnabled:"""),
    (("    Connections {\n        target: SystemServices\n\n        function onNotificationReceived", "    Component.onDestruction:"), ""),
    (("        if (focusEnabled)\n            return;\n\n        shellRoot.forEachWindow", "    }\n\n    function anyOverviewOpen"),
     '''        activities.send({op:"local", app:appName, title:summary, body:body});
'''),
])

# This broker receives the notification's assigned ID, source and action keys.
services = root / "backend/SystemServices.cpp"
if services.is_file():
    edit("backend/SystemServices.cpp", [("    startNotificationMonitor();\n", "")])


edit("DynamicIslandWindow.qml", [
    ("    property var shellRootController: null", """    property var shellRootController: null
    readonly property var activityHub: shellRootController ? shellRootController.activityHub : null
    readonly property bool activityPresentationAllowed: !overviewVisible && !capsuleMouseArea.sideSwipeInteractive
        && ["normal","lyrics","custom"].includes(islandContainer.islandState)
    readonly property bool activityLayerOpen: activities.wanted && activityPresentationAllowed
    readonly property bool sourceActivityExpanded: activityLayerOpen && activities.detailed && !activities.listing
        && activities.activatedSourceId !== "" && activities.activatedSourceId === activities.selected
    readonly property bool sourcePlayerExpanded: islandContainer.expandedLayerVisible && activities.activatedSourceId === "media"
    readonly property bool centerOpen: islandContainer.controlCenterLayerVisible || islandContainer.notificationCenterLayerVisible
    readonly property real capsuleTop: centerOpen ? Math.max(userConfig.islandTopMargin, controlHandle.implicitHeight + 6)
        : userConfig.islandTopMargin
    EdgeHandle {
        screen: root.screen
        leftEdge: true
        opened: islandContainer.notificationCenterLayerVisible
        onActivated: wasOpen => {
            if (wasOpen) islandContainer.smartRestoreState();
            else if (!opened) root.toggleNotificationCenterWindow();
        }
    }
    EdgeHandle {
        id: controlHandle
        screen: root.screen
        leftEdge: false
        opened: islandContainer.controlCenterLayerVisible
        onActivated: wasOpen => {
            if (wasOpen) islandContainer.smartRestoreState();
            else if (!opened) root.toggleControlCenterWindow();
        }
    }
    IdleInhibitor { window: root; enabled: !!root.activityHub && root.activityHub.awake }"""),
    ("    mask: Region {", """    mask: Region {
        Region {
            intersection: Intersection.Combine
            x: Math.floor(activityChips.x); y: Math.floor(activityChips.y)
            width: activityChips.visible ? Math.ceil(activityChips.width) : 0
            height: activityChips.visible ? Math.ceil(activityChips.height) : 0
        }"""),
    ("readonly property bool dismissibleMenu: islandContainer.controlCenterLayerVisible",
     "readonly property bool dismissibleMenu: (root.activityLayerOpen && activities.detailed) || islandContainer.controlCenterLayerVisible"),
    ("compositorIsNiri && dismissibleMenu && !menuWindowActive",
     "compositorIsNiri && dismissibleMenu && !menuWindowActive && !sourceActivityExpanded && !sourcePlayerExpanded"),
    ("&& dismissibleMenu && !connectivityPromptActive)\n            islandContainer.smartRestoreState();",
     """&& dismissibleMenu && !connectivityPromptActive && !sourceActivityExpanded && !sourcePlayerExpanded)
            islandContainer.smartRestoreState();"""),
    ("    WlrLayershell.keyboardFocus: {", """    WlrLayershell.keyboardFocus: {
        if (root.sourceActivityExpanded || root.sourcePlayerExpanded)
            return WlrKeyboardFocus.None;
        if (root.activityLayerOpen && activities.detailed)
            return WlrKeyboardFocus.OnDemand;"""),
    ("    function focusExpandedPlayer() {", """    function focusExpandedPlayer() {
        if (root.sourcePlayerExpanded) return;"""),
    ("        focus: controlCenterLayerVisible", """        focus: (root.activityLayerOpen && activities.detailed && !root.sourceActivityExpanded)
            || controlCenterLayerVisible"""),
    ("""        function showWorkspaceCapsule(wsId) {
            currentWs = wsId;""", """        function showWorkspaceCapsule(wsId) {
            currentWs = wsId;
            if (root.sourceActivityExpanded || root.sourcePlayerExpanded) return;"""),
    ("""        onExpandedLayerVisibleChanged: {
            if (expandedLayerVisible)
                requestExpandedPlayerKeyboardFocus();
            else
                expandedPlayerKeyboardFocusRequested = false;
        }""", """        onExpandedLayerVisibleChanged: {
            if (expandedLayerVisible) {
                if (!root.sourcePlayerExpanded) requestExpandedPlayerKeyboardFocus();
            } else {
                expandedPlayerKeyboardFocusRequested = false;
                if (activities.activatedSourceId === "media") activities.activatedSourceId = "";
            }
        }"""),
    ("    readonly property bool autoHideCanHideNow: autoHideEnabled", """    readonly property bool autoHideCanHideNow: autoHideEnabled
        && !activities.wanted && activities.rows.length === 0"""),
    ("readonly property bool hoverExpandEnabled: configuredHoverExpandAction > 0", """readonly property bool hoverExpandEnabled: configuredHoverExpandAction > 0 && !activities.wanted
        && (configuredHoverExpandAction === 2 || (islandContainer.activePlayer && islandContainer.activePlayer.isPlaying))"""),
    (("        onCurrentTrackChanged: {", "        // --- UI"), ""),
    (("        function showNotificationCapsule(appName, summary, body) {", "        function toggleNotificationExpansionIfNeeded()"),
     """        function showNotificationCapsule(appName, summary, body) {
            if (root.activityHub) root.activityHub.send({op:"local", app:appName, title:summary, body:body});
        }

"""),
    ("        function smartRestoreState() {", """        function smartRestoreState() {
            activities.closeDetails();"""),
    ("""        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {""", """        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (root.activityLayerOpen && activities.detailed) {
                    activities.closeDetails();
                    event.accepted = true;
                    return;
                }
"""),
    ("        readonly property bool timerBubbleWanted: (timerActive && timerRemainingSeconds > 0 || timerCompletionAnimating)",
     "        readonly property bool timerBubbleWanted: timerCompletionAnimating"),
    ("                if (root.overviewVisible) return root.overviewCapsuleWidth;", """                if (root.overviewVisible) return root.overviewCapsuleWidth;
                if (root.activityLayerOpen) return Math.min(root.width - 24, activities.detailed ? 392 : 246);"""),
    ("                if (root.overviewVisible) return root.overviewCapsuleHeight;", """                if (root.overviewVisible) return root.overviewCapsuleHeight;
                if (root.activityLayerOpen && activities.detailed) return activities.detailHeight;"""),
    ("                if (root.overviewVisible) return root.overviewCapsuleRadius;", """                if (root.overviewVisible) return root.overviewCapsuleRadius;
                if (root.activityLayerOpen && activities.detailed) return 26;"""),
    ("        userConfig.islandTopMargin + mainCapsule.targetHeight", "        root.capsuleTop + mainCapsule.targetHeight"),
    ("Math.ceil(userConfig.islandTopMargin + root.connectivityDetailHeight", "Math.ceil(root.capsuleTop + root.connectivityDetailHeight"),
    ("? userConfig.islandTopMargin + 320 + root.controlCenterMaximumExtraHeight",
     "? root.capsuleTop + 320 + root.controlCenterMaximumExtraHeight"),
    ("? userConfig.islandTopMargin + (notificationCenterLoader.item", "? root.capsuleTop + (notificationCenterLoader.item"),
    ("            y: userConfig.islandTopMargin", "            y: root.capsuleTop"),
    ("            x: parent ? parent.width * userConfig.islandPositionX / 100 - width / 2 : 0",
     """            x: !parent ? 0 : islandContainer.controlCenterLayerVisible ? Math.max(0, parent.width - width - 12)
                : islandContainer.notificationCenterLayerVisible ? 12
                : parent.width * userConfig.islandPositionX / 100 - width / 2"""),
    ("                    preparedOverviewOnPress = pressedAction ===", """                    if (mouse.button === Qt.LeftButton && islandContainer.islandState === "normal") return;
                    preparedOverviewOnPress = pressedAction ==="""),
    ("                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)) {\n                        if (islandContainer.toggleNotificationExpansionIfNeeded())",
     """                    if (mouse.button === Qt.LeftButton && islandContainer.islandState === "normal") {
                        islandContainer.showCalendar(); return;
                    }
                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)) {
                        if (islandContainer.toggleNotificationExpansionIfNeeded())"""),
    ("            Loader {\n                id: controlCenterLoader", """            ActivityCapsule {
                id: activities
                anchors.fill: parent
                z: 8
                visible: root.activityLayerOpen
                hub: root.activityHub; player: islandContainer.activePlayer
                track: islandContainer.currentTrack; artist: islandContainer.currentArtist; art: islandContainer.currentArtUrl
                timerActive: islandContainer.timerActive; timerSeconds: islandContainer.timerRemainingSeconds
                onOpenPlayer: islandContainer.showExpandedPlayer(false)
                onOpenTimer: islandContainer.showExpandedTimerPage()
                onEditingRequested: {
                    if (root.sourceActivityExpanded) {
                        activatedSourceId = "";
                        if (root.compositorIsNiri && !root.menuWindowActive) {
                            root.remappingMenu = true;
                            menuRemapTimer.restart();
                        }
                    }
                }
            }
            Loader {
                id: controlCenterLoader"""),
    ("onControlPressed: islandContainer.suppressCapsuleClick()", """onControlPressed: {
                            if (root.sourcePlayerExpanded) {
                                activities.activatedSourceId = "";
                                islandContainer.requestExpandedPlayerKeyboardFocus();
                            }
                            islandContainer.suppressCapsuleClick();
                        }"""),
    ("onBackgroundClicked: islandContainer.smartRestoreState()", """onBackgroundClicked: {
                            if (islandContainer.activePlayer) activities.activatePlayerSource();
                            else islandContainer.smartRestoreState();
                        }"""),
    ("                    ControlCenterLayer {", """                    ControlCenterLayer {
                        activityHub: root.activityHub
                        onDismissRequested: islandContainer.smartRestoreState()
                        onTimerRequested: islandContainer.showExpandedTimerPage()"""),
    (("                    NotificationCenterLayer {", "                }\n            }\n\n            Loader {\n                id: wallpaperPickerLoader"),
     "                    ActivityHistory { hub: root.activityHub }\n"),
    ("        Item {\n            id: fileShelfBubble", """        Row {
            id: activityChips
            readonly property bool expandedMusic: islandContainer.expandedLayerVisible && activities.playing
            readonly property var others: expandedMusic ? activities.rows.filter(r => r.kind !== "music") : activities.secondary
            readonly property var smallItem: expandedMusic ? others[0] || null : activities.chip
            spacing: 3
            x: Math.min(parent.width - width, mainCapsule.x + mainCapsule.width + 5)
            y: mainCapsule.y + (userConfig.islandHeight - height) / 2
            z: 8; opacity: root.autoHideProgress
            visible: (root.activityPresentationAllowed || expandedMusic) && !!smallItem && opacity > 0.01
            IslandButton {
                visible: !!activityChips.smallItem
                text: activityChips.smallItem ? activities.glyph(activityChips.smallItem.kind) : ""
                description: activityChips.smallItem ? activityChips.smallItem.title : ""
                onClicked: {
                    const row = activityChips.smallItem;
                    if (activityChips.expandedMusic) islandContainer.smartRestoreState();
                    activities.expand(row);
                }
            }
            IslandButton {
                visible: activityChips.others.length > 1
                text: "+" + Math.max(0, activityChips.others.length - 1); description: "All activities"
                onClicked: {
                    if (activityChips.expandedMusic) islandContainer.smartRestoreState();
                    activities.closeDetails(); activities.listing = true;
                }
            }
        }
        Item {
            id: fileShelfBubble"""),
])


edit("qml/controlcenter/ControlCenterLayer.qml", [
    ("    signal lockRequested()", """    signal lockRequested()
    signal timerRequested()
    signal dismissRequested()
    property var activityHub: null"""),
    ("    property int batteryCapacity: 0", "    property int batteryCapacity: -1"),
    ('["swaync-client", "--get-dnd"]', '["makoctl", "mode"]'),
    ('''stdout: SplitParser {
            onRead: function(line) {
                const enabled = line.trim().toLowerCase() === "true";''', '''stdout: StdioCollector {
            onStreamFinished: {
                const enabled = text.trim().split(/\\s+/).includes("tide-silent");'''),
    ('["swaync-client", "-dn"]', '["makoctl", "mode", "-a", "tide-silent"]'),
    ('["swaync-client", "-df"]', '["makoctl", "mode", "-r", "tide-silent"]'),
    ("    readonly property real batteryModeCardHeight: 80", """    readonly property real profileCardHeight: batteryCapacity >= 0 && tlpControlsEnabled ? 58 : 0
    readonly property real batteryModeCardHeight: 112 + (profileCardHeight ? profileCardHeight + 4 : 0)"""),
    ("controlCenterExtraHeight: 12 + batteryDrawerHandleHeight", "controlCenterExtraHeight: 12 + batteryDrawerHandleHeight - (brightnessLevel < 0 ? 88 : 0)"),
    ("{ item: focusButton,", "{ item: quickDrawer.itemAt(0),"),
    ("{ item: nightLightButton,", "{ item: quickDrawer.itemAt(1),"),
    ("            Row {\n                anchors.right: parent.right\n                anchors.rightMargin: 2",
     """            Row {
                id: batteryReadout
                visible: controlCenter.batteryCapacity >= 0
                anchors.right: toolsRow.left
                anchors.rightMargin: 6"""),
    ("            Row {\n                id: batteryReadout", """            Row {
                id: toolsRow
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                IslandButton { text: "⚙"; description: "Settings"; onClicked: { Quickshell.execDetached(["tide-island-config-app"]); controlCenter.dismissRequested() } }
                IslandButton { text: "⏻"; description: "Power"; onClicked: controlCenter.powerViewActive = true }
            }
            Row {
                id: batteryReadout"""),
    ("import Quickshell.Bluetooth", "import Quickshell\nimport Quickshell.Bluetooth"),
    ("                y: -height + controlCenter.batteryDrawerProgress * height\n                width: batteryDrawer.cardWidth\n                height: controlCenter.batteryModeCardHeight",
     """                y: (controlCenter.batteryDrawerProgress - 1) * controlCenter.batteryModeCardHeight
                width: parent.width
                height: controlCenter.profileCardHeight"""),
    ("                visible: controlCenter.tlpControlsEnabled", "                visible: controlCenter.profileCardHeight > 0"),
    (("            Rectangle {\n                id: quickTogglesCard", "            Rectangle {\n                id: batteryDrawerTunnelShade"), """            QuickDrawer {
                id: quickDrawer
                y: batteryModeCard.y + (controlCenter.profileCardHeight ? controlCenter.profileCardHeight + 4 : 0)
                width: parent.width; height: 112
                visible: controlCenter.batteryDrawerProgress > 0.01
                enabled: controlCenter.batteryDrawerOpen
                hub: controlCenter.activityHub
                control: controlCenter
            }

"""),
    ("            id: brightnessCard\n", "            id: brightnessCard\n            visible: controlCenter.brightnessLevel >= 0\n"),
])
edit("qml/island/IslandSystemState.qml", [
    ('            if (errorString === "" && value >= 0)\n                root.currentBrightness = root.clamp01(value);',
     '            root.currentBrightness = errorString === "" && value >= 0 ? root.clamp01(value) : -1;'),
])
edit("qml/connectivity/ConnectivityDetailShell.qml", [
    ("readonly property real shownX: rightSide", """readonly property bool showOnRight: rightSide
        ? capsuleX + capsuleWidth + detailGap + width <= availableWidth - 12
        : capsuleX < width + detailGap + 12
    readonly property real shownX: showOnRight"""),
    ("hiddenX: shownX + (rightSide ?", "hiddenX: shownX + (showOnRight ?"),
])
edit("qml/lockscreen/LockScreenController.qml", [
    ('hasBattery: SysBackend.batteryStatus !== "" && SysBackend.batteryStatus !== "Unknown" && SysBackend.batteryStatus !== "Not present"',
     'hasBattery: SysBackend.batteryCapacity >= 0'),
])
edit("qml/lockscreen/LockScreenView.qml", [
    ('|| option("showBattery", true) ? 88', '|| (hasBattery && option("showBattery", true)) ? 88'),
    ('visible: root.option("showBattery", true)', 'visible: root.hasBattery && root.option("showBattery", true)'),
])
