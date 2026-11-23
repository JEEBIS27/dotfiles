import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import IslandBackend
import "qml/common"
import "qml/design"
import "qml/controlcenter"
import "qml/connectivity"
import "qml/island"
import "qml/workspace"

PanelWindow {
    id: root
    property var shellRootController: null
    readonly property var activityHub: shellRootController ? shellRootController.activityHub : null
    readonly property bool activityPresentationAllowed: !overviewVisible && !capsuleMouseArea.sideSwipeInteractive
        && ["normal","lyrics","custom"].includes(islandContainer.islandState)
    readonly property bool activityLayerOpen: (activities.detailed || !!handoff.main || !!root.activityHub?.errorText) && activityPresentationAllowed
    readonly property bool sourceActivityExpanded: activityLayerOpen && activities.detailed && !activities.listing
        && activities.activatedSourceId !== "" && activities.activatedSourceId === activities.selected
    readonly property bool sourcePlayerExpanded: islandContainer.expandedLayerVisible && activities.activatedSourceId === "media"
    readonly property bool centerOpen: islandContainer.controlCenterLayerVisible || islandContainer.notificationCenterLayerVisible
    // Niri snaps its layout gap and focus ring to the output's physical pixels.
    readonly property real centerInset: snapToOutputPixel(4)
    readonly property real capsuleFrameWidth: capsuleFrame.alignedWidth
    readonly property real chipFrameWidth: activityChip.background?.alignedFrameWidth ?? 0
    readonly property real centerCornerRadius: 15
    readonly property real compactCapsuleHeight: snapToOutputPixel(userConfig.islandHeight)

    // Sample a small patch adjacent to the capsule. This follows windows as well
    // as the wallpaper without feeding the Island's own pixels back into its outline.
    property real compactKeyline: 1
    Behavior on compactKeyline { NumberAnimation { duration: 200 } }
    Timer {
        interval: 1800
        repeat: true
        triggeredOnStart: true
        running: root.visible && !!root.screen && mainCapsule.roundedCapsule
            && root.autoHideTargetVisible && userConfig.islandFrameWidth > 0
            && !root.shellRootController?.sessionLocked
        onTriggered: {
            if (backdrop.running) return
            const sx = mainCapsule.x > 20 ? mainCapsule.x - 16 : mainCapsule.x + mainCapsule.width + 55
            const x = Math.round(root.screen.x + Math.max(0, Math.min(root.width - 8, sx)))
            const y = Math.round(root.screen.y + mainCapsule.y + mainCapsule.height / 2 - 3)
            backdrop.command = ["bash", "-o", "pipefail", "-c",
                'grim -g "$1" -s 1 -t ppm - | magick ppm:- -colorspace gray -format "%[fx:mean]" info:',
                "island-keyline", x + "," + y + " 8x6"]
            backdrop.running = true
        }
    }
    Process {
        id: backdrop
        stdout: StdioCollector {
            onStreamFinished: {
                const luminance = parseFloat(this.text)
                if (Number.isFinite(luminance))
                    root.compactKeyline = Math.min(1, Math.max(0, (0.26 - luminance) / 0.18))
            }
        }
    }

    function snapToOutputPixel(value) {
        const scale = devicePixelRatio > 0 ? devicePixelRatio : 1;
        return Math.round(value * scale) / scale;
    }
    readonly property real capsuleTop: centerOpen ? centerInset : Math.max(capsuleFrameWidth, snapToOutputPixel(userConfig.islandTopMargin))
    EdgeHandle {
        screen: root.screen
        leftEdge: true
        opened: islandContainer.notificationCenterLayerVisible
        onActivated: wasOpen => {
            if (wasOpen && !centerExit.running) islandContainer.smartRestoreState();
            else if (wasOpen) islandContainer.showNotificationCenter();
            else if (!opened) root.toggleNotificationCenterWindow();
        }
    }
    EdgeHandle {
        screen: root.screen
        leftEdge: false
        opened: islandContainer.controlCenterLayerVisible
        onActivated: wasOpen => {
            if (wasOpen && !centerExit.running) islandContainer.smartRestoreState();
            else if (wasOpen) islandContainer.showControlCenter();
            else if (!opened) root.toggleControlCenterWindow();
        }
    }
    IdleInhibitor { window: root; enabled: !!root.activityHub && root.activityHub.awake }
    property string overviewPhase: "closed"
    property bool overviewPreloading: false
    readonly property bool overviewPreparing: overviewPhase === "preparing"
    readonly property bool overviewVisible: overviewPhase === "preparing" || overviewPhase === "opening" || overviewPhase === "open"
    readonly property bool overviewMounted: overviewPhase !== "closed" || overviewPreloading
    readonly property bool overviewLoaderActive: !compositorIsNiri
        && (overviewMounted || overviewUnloadGraceTimer.running)
    readonly property bool overviewDataReady: overviewLoader.item
        ? !!overviewLoader.item.overviewDataReady
        : false
    readonly property bool overviewWallpaperReady: overviewWallpaperCache.ready
    readonly property bool overviewVisualReady: overviewDataReady && overviewWallpaperReady
    readonly property bool overviewContentVisible: (overviewPhase === "opening" || overviewPhase === "open")
        && overviewVisualReady
    readonly property bool compositorIsNiri: CompositorBackend.compositor === "niri"
    readonly property int compositorRevision: CompositorBackend.revision
    readonly property string screenOutputName: screen && screen.name !== undefined ? String(screen.name) : ""
    readonly property var hyprlandIntegration: hyprlandIntegrationLoader.item
    readonly property var hyprMonitor: hyprlandIntegration ? hyprlandIntegration.monitor : null
    readonly property string hyprMonitorName: hyprlandIntegration ? hyprlandIntegration.monitorName : ""
    readonly property string compositorOutputName: compositorIsNiri ? screenOutputName : hyprMonitorName
    readonly property bool monitorFocused: {
        compositorRevision;
        return compositorIsNiri
            ? CompositorBackend.isOutputFocused(screenOutputName)
            : (hyprlandIntegration ? hyprlandIntegration.monitorFocused : false);
    }
    readonly property bool connectivityPromptActive: controlCenterLoader.item
        ? controlCenterLoader.item.hasConnectivityPrompt
        : false
    readonly property var controlCenterRef: controlCenterLoader.item
    readonly property int currentMonitorWorkspaceId: {
        compositorRevision;
        return compositorIsNiri
            ? CompositorBackend.activeWorkspaceIndexForOutput(screenOutputName)
            : (hyprlandIntegration ? hyprlandIntegration.workspaceId : 1);
    }
    onCurrentMonitorWorkspaceIdChanged: {
        if (islandContainer?.islandState === "app_queue") islandContainer.smartRestoreState()
    }
    readonly property bool screenRecordingActive: shellRootController
        && shellRootController.screenRecordingActive !== undefined
        ? !!shellRootController.screenRecordingActive
        : false
    property bool autoHideVisible: false
    property bool autoHidePointerInside: false
    property bool autoHideForcedHidden: false
    property string autoHideRevealSource: "none"

    readonly property var userConfig: UserConfig

    WeatherService {
        id: fallbackWeatherService
        weatherEnabled: (!root.shellRootController || !root.shellRootController.weatherService)
            && (userConfig ? userConfig.weatherEnabled : true)
    }

    readonly property var weatherService: (root.shellRootController && root.shellRootController.weatherService)
        ? root.shellRootController.weatherService
        : fallbackWeatherService

    Loader {
        id: hyprlandIntegrationLoader

        active: !root.compositorIsNiri
        asynchronous: false
        source: active ? "qml/island/HyprlandWindowIntegration.qml" : ""
    }

    Binding {
        target: hyprlandIntegrationLoader.item
        property: "screenObject"
        value: root.screen
        when: hyprlandIntegrationLoader.item !== null
    }

    color: StyleTokens.transparent
    WlrLayershell.namespace: "tide-island"
    anchors { top: true; left: true; right: true }
    // Blur only the visible material, never the full-width layer surface or
    // the invisible gesture strip. The input mask remains independent.
    readonly property real materialOpacity: userConfig.islandBackgroundOpacity / 100
    readonly property color materialColor: Qt.alpha(StyleTokens.panel, materialOpacity)
    BackgroundEffect.blurRegion: root.userConfig.islandBlurEnabled && root.autoHideTargetVisible
        && root.materialOpacity < 1
        ? nativeBlurRegion : null

    readonly property Region nativeBlurRegions: Region {
        id: nativeBlurRegion

        InsetBlurRegion {
            surface: mainCapsule
            active: mainCapsule.opacity > 0.01
            surfaceRadius: mainCapsule.radius
        }
        InsetBlurRegion {
            surface: appBubble
            active: appBubble.visible && appBubble.width > 1
            surfaceRadius: appBubble.radius
        }
        InsetBlurRegion {
            surface: fileShelfBubble
            transformDependencies: [clickMerge.phase]
            active: fileShelfBubble.visible && fileShelfBubble.opacity > 0.01
            surfaceRadius: fileShelfBubble.width / 2
        }
        InsetBlurRegion {
            surface: timerBubble
            transformDependencies: [clickMerge.phase]
            active: timerBubble.visible && timerBubble.opacity > 0.01
            surfaceRadius: timerBubble.width / 2
        }
        InsetBlurRegion {
            surface: activityChip
            active: activityChip.visible && activityChips.opacity > 0.01
            surfaceRadius: activityChip.surfaceRadius
            transformDependencies: [activityChips.x, activityChips.y, clickMerge.phase]
        }
        InsetBlurRegion {
            surface: moreActivityChip
            active: moreActivityChip.visible && activityChips.opacity > 0.01
            surfaceRadius: moreActivityChip.surfaceRadius
            transformDependencies: [activityChips.x, activityChips.y, clickMerge.phase]
        }
        InsetBlurRegion {
            surface: wifiConnectivityDetailShell.surfaceItem
            active: wifiConnectivityDetailShell.visible && wifiConnectivityDetailShell.opacity > 0.01
            surfaceRadius: root.centerCornerRadius
            transformDependencies: [wifiConnectivityDetailShell.x, wifiConnectivityDetailShell.y,
                wifiConnectivityDetailShell.panelScale, mainCapsule.height]
        }
        InsetBlurRegion {
            surface: bluetoothConnectivityDetailShell.surfaceItem
            active: bluetoothConnectivityDetailShell.visible && bluetoothConnectivityDetailShell.opacity > 0.01
            surfaceRadius: root.centerCornerRadius
            transformDependencies: [bluetoothConnectivityDetailShell.x, bluetoothConnectivityDetailShell.y,
                bluetoothConnectivityDetailShell.panelScale, mainCapsule.height]
        }
        InsetBlurRegion {
            surface: powerConnectivityDetailShell.surfaceItem
            active: powerConnectivityDetailShell.visible && powerConnectivityDetailShell.opacity > 0.01
            surfaceRadius: root.centerCornerRadius
            transformDependencies: [powerConnectivityDetailShell.x, powerConnectivityDetailShell.y,
                powerConnectivityDetailShell.panelScale, mainCapsule.height]
        }
        InsetBlurRegion {
            surface: calendarNoteShell.surfaceItem
            active: calendarNoteShell.visible && calendarNoteShell.opacity > 0.01
            surfaceRadius: root.centerCornerRadius
            transformDependencies: [calendarNoteShell.x, calendarNoteShell.y, calendarNoteShell.panelScale]
        }
        // Keep the blur bounds within the layer surface as panels resize.
        Region {
            intersection: Intersection.Intersect
            width: root.width
            height: root.height
        }
    }

    mask: Region {
        Region {
            intersection: Intersection.Combine
            x: Math.floor(activityChips.x - root.chipFrameWidth)
            y: Math.floor(activityChips.y - root.chipFrameWidth)
            width: activityChips.visible
                ? Math.ceil(activityChips.x + activityChips.width + root.chipFrameWidth) - x : 0
            height: activityChips.visible
                ? Math.ceil(activityChips.y + activityChips.height + root.chipFrameWidth) - y : 0
        }
        // Input is the union of the island's visible surfaces plus a compact top
        // gesture strip. The gesture strip must not grow with expanded content.
        Region {
            x: Math.floor(root.topGestureInputX)
            y: 0
            width: Math.ceil(Math.max(root.topGestureInputWidth, root.autoHideRevealHeight > 0 ? root.autoHideRevealWidth : 0))
            height: Math.ceil(Math.max(root.topGestureInputHeight, root.autoHideRevealHeight))
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(capsuleFrame.x + capsuleFrame.width * (1 - mainCapsule.revealWidthScale) / 2)
            y: Math.floor(capsuleFrame.y)
            width: root.autoHideProgress > 0.01
                ? Math.ceil(capsuleFrame.x + capsuleFrame.width * (1 + mainCapsule.revealWidthScale) / 2) - x : 0
            height: root.autoHideProgress > 0.01
                ? Math.ceil(mainCapsule.y + (mainCapsule.height + capsuleFrame.extension) * mainCapsule.revealHeightScale) - y : 0
        }

        // Keep the corner gutter on the same input surface as the open panel.
        // A click on that gutter would otherwise focus the window underneath.
        Region {
            intersection: Intersection.Combine
            x: islandContainer.controlCenterLayerVisible ? Math.floor(capsuleFrame.x) : 0
            y: 0
            width: !root.centerOpen ? 0 : islandContainer.controlCenterLayerVisible
                ? Math.ceil(root.width) - x : Math.ceil(capsuleFrame.x + capsuleFrame.width)
            height: root.centerOpen ? Math.ceil(capsuleFrame.y + capsuleFrame.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(fileShelfBubble.x)
            y: Math.floor(fileShelfBubble.y)
            width: fileShelfBubble.visible ? Math.ceil(fileShelfBubble.width) : 0
            height: fileShelfBubble.visible ? Math.ceil(fileShelfBubble.height) : 0
        }
        
        Region {
            intersection: Intersection.Combine
            x: Math.floor(timerBubble.x)
            y: Math.floor(timerBubble.y)
            width: timerBubble.visible ? Math.ceil(timerBubble.width) : 0
            height: timerBubble.visible ? Math.ceil(timerBubble.height) : 0
        }

        // Add existing detail shells
        Region {
            intersection: Intersection.Combine
            x: Math.floor(wifiConnectivityDetailShell.x)
            y: Math.floor(wifiConnectivityDetailShell.y)
            width: wifiConnectivityDetailShell.visible ? Math.ceil(wifiConnectivityDetailShell.width) : 0
            height: wifiConnectivityDetailShell.visible ? Math.ceil(wifiConnectivityDetailShell.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(bluetoothConnectivityDetailShell.x)
            y: Math.floor(bluetoothConnectivityDetailShell.y)
            width: bluetoothConnectivityDetailShell.visible ? Math.ceil(bluetoothConnectivityDetailShell.width) : 0
            height: bluetoothConnectivityDetailShell.visible ? Math.ceil(bluetoothConnectivityDetailShell.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(powerConnectivityDetailShell.x)
            y: Math.floor(powerConnectivityDetailShell.y)
            width: powerConnectivityDetailShell.visible ? Math.ceil(powerConnectivityDetailShell.width) : 0
            height: powerConnectivityDetailShell.visible ? Math.ceil(powerConnectivityDetailShell.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(calendarNoteShell.x)
            y: Math.floor(calendarNoteShell.y)
            width: calendarNoteShell.visible ? Math.ceil(calendarNoteShell.width) : 0
            height: calendarNoteShell.visible ? Math.ceil(calendarNoteShell.height) : 0
        }
    }
    readonly property real capsuleWindowHeight: Math.ceil(
        root.capsuleTop + (root.centerOpen ? mainCapsule.panelTargetHeight : mainCapsule.targetHeight) + 12
    )
    readonly property real connectivityDetailWindowHeight: root.anyConnectivityDetailMounted
        ? Math.ceil(root.capsuleTop + root.connectivityDetailHeight + 12)
        : 0
    readonly property real overviewWindowHeight: root.overviewVisible
        ? Math.ceil(userConfig.islandTopMargin + root.overviewCapsuleHeight + 8)
        : 0
    readonly property real requestedWindowHeight: Math.max(
        root.notificationCenterWindowHeight,
        root.capsuleWindowHeight,
        root.connectivityDetailWindowHeight,
        root.overviewWindowHeight,
        Math.ceil(root.controlCenterWindowHeight)
    )
    // Grow the layer surface immediately, but keep the old extent while the
    // capsule finishes its collapse animation. A later expansion interrupts
    // the pending shrink instead of letting a stale timer clip new content.
    property real retainedWindowHeight: 0
    implicitHeight: Math.max(root.requestedWindowHeight, root.retainedWindowHeight)

    function reconcileWindowHeight() {
        if (root.requestedWindowHeight >= root.retainedWindowHeight) {
            windowShrinkTimer.stop();
            root.retainedWindowHeight = root.requestedWindowHeight;
            return;
        }

        windowShrinkTimer.restart();
    }

    onRequestedWindowHeightChanged: root.reconcileWindowHeight()
    Component.onCompleted: root.retainedWindowHeight = root.requestedWindowHeight

    exclusiveZone: Math.ceil(root.baseExclusiveZone * root.exclusiveZoneProgress)
    WlrLayershell.layer: islandContainer.wallpaperPickerLayerVisible
        || islandContainer.applicationLauncherLayerVisible
        || islandContainer.fileShelfLayerVisible
        || islandContainer.clipboardLayerVisible
        || islandContainer.weatherLayerVisible
        || islandContainer.calendarLayerVisible
        ? WlrLayer.Overlay
        : WlrLayer.Top
    readonly property bool dismissibleMenu: (root.activityLayerOpen && activities.detailed) || islandContainer.controlCenterLayerVisible
        || islandContainer.notificationCenterLayerVisible
        || islandContainer.wallpaperPickerLayerVisible
        || islandContainer.applicationLauncherLayerVisible
        || islandContainer.fileShelfLayerVisible
        || islandContainer.clipboardLayerVisible
        || islandContainer.weatherLayerVisible
        || islandContainer.calendarLayerVisible
        || (islandContainer.expandedLayerVisible && !islandContainer.expandedByPlayerAutoOpen)
        || islandContainer.bluetoothExpandedLayerVisible
    readonly property bool menuWindowActive: mainCapsule.Window.active
    property bool remappingMenu: false
    visible: !remappingMenu
    onDismissibleMenuChanged: {
        // Niri grants on-demand focus when the layer surface is mapped.
        if (compositorIsNiri && dismissibleMenu && !menuWindowActive && !sourceActivityExpanded && !sourcePlayerExpanded) {
            remappingMenu = true;
            menuRemapTimer.restart();
        }
    }
    Timer {
        id: menuRemapTimer
        interval: 0
        onTriggered: root.remappingMenu = false
    }
    onMenuWindowActiveChanged: {
        if (!menuWindowActive && !remappingMenu && compositorIsNiri
                && dismissibleMenu && !connectivityPromptActive && !sourceActivityExpanded && !sourcePlayerExpanded)
            islandContainer.smartRestoreState();
    }
    WlrLayershell.keyboardFocus: {
        if (root.sourceActivityExpanded || root.sourcePlayerExpanded)
            return WlrKeyboardFocus.None;
        if (root.activityLayerOpen && activities.detailed)
            return WlrKeyboardFocus.OnDemand;
        if (compositorIsNiri && dismissibleMenu && !connectivityPromptActive)
            return WlrKeyboardFocus.OnDemand;
        if (islandContainer.controlCenterLayerVisible
                || islandContainer.notificationCenterLayerVisible
                || islandContainer.wallpaperPickerLayerVisible
                || islandContainer.applicationLauncherLayerVisible
                || islandContainer.clipboardLayerVisible
                || islandContainer.weatherLayerVisible
                || islandContainer.calendarLayerVisible)
            return WlrKeyboardFocus.Exclusive;
        if (islandContainer.fileShelfLayerVisible)
            return WlrKeyboardFocus.OnDemand;
        // Keep keyboard focus on the overview until an overview action closes it.
        // Click-to-focus closes the overview before focusing the selected client.
        if (root.monitorFocused && root.overviewVisible)
            return WlrKeyboardFocus.Exclusive;
        if (islandContainer.expandedPlayerKeyboardFocusRequested)
            return WlrKeyboardFocus.Exclusive;
        if (root.monitorFocused && root.connectivityPromptActive)
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.None;
    }
    readonly property string iconFontFamily: userConfig.iconFontFamily
    readonly property string textFontFamily: userConfig.textFontFamily
    readonly property string heroFontFamily: userConfig.heroFontFamily
    readonly property string timeFontFamily: userConfig.timeFontFamily
    readonly property int bodyFontSize: userConfig.bodyFontSize
    readonly property int titleFontSize: userConfig.titleFontSize
    readonly property int iconFontSize: userConfig.iconFontSize
    readonly property string defaultSplitIcon: "\ud83c\udfa7"
    readonly property string notificationStatusIcon: "\uf0f3"
    readonly property real overviewWindowCornerRadius: 12
    readonly property int dynamicIslandAcceptedButtons: userConfig.mouseButtonsMask([
        1,
        2,
        userConfig.dynamicIslandPrimaryButton,
        userConfig.dynamicIslandSecondaryButton,
        userConfig.dynamicIslandMiddleButton
    ])
    readonly property int configuredHoverExpandAction: {
        const action = Number(userConfig.hoverExpandAction);
        return isNaN(action) ? 0 : Math.max(0, Math.min(2, Math.round(action)));
    }
    readonly property real baseExclusiveZone: userConfig.islandExclusiveZone
    readonly property bool hoverExpandEnabled: configuredHoverExpandAction > 0 && !activities.wanted
        && (configuredHoverExpandAction === 2 || (islandContainer.activePlayer && islandContainer.activePlayer.isPlaying))
    readonly property bool topGestureInputActive: !root.overviewVisible && islandContainer.canShowSideSwipe
    readonly property bool autoHideRuntimeEnabled: !shellRootController
        || shellRootController.islandAutoHideRuntimeEnabled === undefined
        || !!shellRootController.islandAutoHideRuntimeEnabled
    readonly property bool autoHideEnabled: userConfig.islandAutoHideEnabled && autoHideRuntimeEnabled
    readonly property bool autoHideRestingState: islandContainer.islandState === "normal"
        || islandContainer.islandState === "custom"
        || islandContainer.islandState === "lyrics"
        || islandContainer.levelOsdVisible || islandContainer.islandState === "app_queue"
    readonly property bool autoHideCanHideNow: autoHideEnabled
        && !activities.wanted && activities.rows.length === 0
        && autoHideRestingState
        && !root.overviewVisible
        && !root.connectivityPromptActive
        && !root.anyConnectivityDetailMounted
    readonly property bool autoHideMustShow: !autoHideRestingState
        || root.overviewVisible
        || root.connectivityPromptActive
        || root.anyConnectivityDetailMounted
    readonly property bool islandNormallyVisible: autoHideMustShow
        || (!autoHideForcedHidden && (!autoHideEnabled || autoHideVisible))
    readonly property bool autoHideTargetVisible: !!clickMerge.source || islandContainer.islandState === "app_queue" || islandNormallyVisible || islandPeekTimer.running || islandContainer.levelOsdVisible
    readonly property bool autoHideSuppressesTransientReveal: (autoHideEnabled || autoHideForcedHidden)
        && !autoHideTargetVisible
    property real autoHideProgress: autoHideTargetVisible ? 1 : 0
    readonly property bool exclusiveZoneTargetActive: (!autoHideEnabled && islandNormallyVisible)
        || (autoHideRevealSource === "edge" && autoHideTargetVisible)
        || islandContainer.notificationLayerVisible
    property real exclusiveZoneProgress: exclusiveZoneTargetActive ? 1 : 0
    readonly property real autoHideRevealWidth: Math.min(root.width, userConfig.islandWidth)
    // Only the top-edge pixels directly above the resting capsule can wake it.
    readonly property real autoHideRevealHeight: autoHideEnabled && !centerOpen && autoHideRestingState ? 1 : 0
    readonly property real autoHideRevealX: Math.max(0, Math.min(root.width - autoHideRevealWidth,
        root.width * userConfig.islandPositionX / 100 - autoHideRevealWidth / 2))
    readonly property real topGestureInputX: autoHideRevealX
    readonly property real topGestureInputWidth: topGestureInputActive ? autoHideRevealWidth : 0
    readonly property real topGestureInputHeight: topGestureInputActive
        ? Math.max(autoHideRevealHeight, autoHideTargetVisible ? capsuleTop : 0) : 0
    readonly property real overviewCapsuleWidth: islandContainer.overviewView ? islandContainer.overviewView.width : 760
    readonly property real overviewCapsuleHeight: islandContainer.overviewView ? islandContainer.overviewView.height : 308
    readonly property color overviewCapsuleColor: islandContainer.overviewView
        ? islandContainer.overviewView.cardColor
        : StyleTokens.overviewCard
    readonly property color overviewCapsuleBorderColor: islandContainer.overviewView
        ? islandContainer.overviewView.cardBorderColor
        : StyleTokens.overviewBorder
    property bool wifiConnectivityDetailOpen: false
    property bool wifiConnectivityDetailMounted: false
    property bool bluetoothConnectivityDetailOpen: false
    property bool bluetoothConnectivityDetailMounted: false
    property bool powerConnectivityDetailOpen: false
    property bool powerConnectivityDetailMounted: false
    readonly property bool anyConnectivityDetailMounted: wifiConnectivityDetailMounted || bluetoothConnectivityDetailMounted || powerConnectivityDetailMounted
    readonly property real connectivityDetailWidth: 318
    readonly property real connectivityDetailHeight: 404
    readonly property real controlCenterMaximumExtraHeight: controlCenterLoader.item
        ? controlCenterLoader.item.controlCenterMaximumExtraHeight
        : 120
    readonly property real controlCenterWindowHeight: islandContainer.controlCenterLayerVisible
        ? root.capsuleTop + 320 + root.controlCenterMaximumExtraHeight + 12
        : 0

    readonly property real notificationCenterWindowHeight: islandContainer.notificationCenterLayerVisible
        ? root.capsuleTop + (notificationCenterLoader.item ? notificationCenterLoader.item.contentHeight : 400) + 6
        : 0
    readonly property real connectivityDetailGap: 16
    readonly property int connectivityDetailAnimationDuration: 360
    readonly property string overviewWallpaperSource: overviewWallpaperCache.effectiveSource
    property string wallpaperPickerActiveWallpaper: userConfig.wallpaperPath

    Behavior on autoHideProgress {
        NumberAnimation {
            id: capsuleRevealAnimation
            duration: root.autoHideTargetVisible ? 260 : 210
            easing.type: root.autoHideTargetVisible ? Easing.OutQuint : Easing.InCubic
        }
    }

    readonly property bool escapeTargetVisible: dismissibleMenu || overviewVisible
        || connectivityPromptActive || islandContainer.expandedLayerVisible
        || islandContainer.islandState === "split" || islandContainer.islandState === "long_capsule"
        || islandContainer.islandState === "app_queue"
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
    }

    Behavior on exclusiveZoneProgress {
        NumberAnimation {
            duration: root.exclusiveZoneTargetActive ? 120 : 300
            easing.type: root.exclusiveZoneTargetActive ? Easing.OutCubic : Easing.InCubic
        }
    }

    function setAutoHideRevealSource(source) {
        if (source === undefined || source === null)
            return;

        const nextSource = String(source);
        autoHideRevealSource = nextSource === "edge" || nextSource === "state" || nextSource === "manual"
            ? nextSource
            : "manual";
    }

    function showAutoHiddenIsland(source) {
        setAutoHideRevealSource(source);
        autoHideForcedHidden = false;
        if (!autoHideEnabled) {
            autoHideHideTimer.stop();
            autoHideVisible = true;
            return;
        }

        autoHideHideTimer.stop();
        autoHideVisible = true;
    }

    function scheduleAutoHide() {
        if (!autoHideEnabled) {
            autoHideHideTimer.stop();
            autoHideVisible = true;
            return;
        }

        if (!autoHideCanHideNow) {
            autoHideHideTimer.stop();
            showAutoHiddenIsland("state");
            return;
        }

        if (autoHidePointerInside) {
            autoHideHideTimer.stop();
            return;
        }

        autoHideHideTimer.interval = userConfig.durations.islandAutoHideDelayMs;
        autoHideHideTimer.restart();
    }

    function hideAutoHiddenIsland(force) {
        if (force === undefined) force = false;
        if (!autoHideEnabled) {
            autoHideHideTimer.stop();
            if (!force && autoHideMustShow)
                return;
            autoHideForcedHidden = true;
            autoHideRevealSource = "none";
            autoHideVisible = false;
            return;
        }

        if (!force && (!autoHideCanHideNow || autoHidePointerInside))
            return;

        autoHideHideTimer.stop();
        autoHideForcedHidden = false;
        autoHideRevealSource = "none";
        autoHideVisible = false;
    }

    function toggleAutoHiddenIsland() {
        if (autoHideTargetVisible)
            hideAutoHiddenIsland(false);
        else
            showAutoHiddenIsland("manual");
    }

    Timer {
        id: islandPeekTimer
        interval: userConfig.durations.islandAutoHideDelayMs
    }

    function peekIslandWindow() {
        islandPeekTimer.restart();
    }

    function showIslandWindow() {
        islandPeekTimer.stop();
        showAutoHiddenIsland("manual");
    }

    function hideIslandWindow() {
        islandPeekTimer.stop();
        autoHidePointerInside = false;
        hideAutoHiddenIsland(false);
    }

    function toggleIslandWindow() {
        toggleAutoHiddenIsland();
    }

    function refreshAutoHideWindow() {
        if (autoHideEnabled)
            scheduleAutoHide();
        else
            showAutoHiddenIsland("manual");
    }

    function beginOverviewOpening() {
        if (!overviewPreparing) return;
        if (overviewLoader.status !== Loader.Ready || !overviewVisualReady) return;
        overviewPreloading = false;
        overviewPhase = "opening";
        overviewRevealTimer.restart();
    }

    function prepareOverview() {
        if (compositorIsNiri) return;
        if (overviewPhase !== "closed") return;
        overviewUnloadGraceTimer.stop();
        overviewPreloading = true;
        overviewPreloadExpireTimer.restart();
    }

    function cancelPreparedOverview() {
        if (compositorIsNiri) return;
        if (overviewPhase !== "closed") return;
        overviewPreloadExpireTimer.stop();
        overviewPreloading = false;
    }

    function openOverview() {
        if (compositorIsNiri)
            return;
        if (overviewPhase !== "closed") return;
        overviewUnloadGraceTimer.stop();
        overviewPreloadExpireTimer.stop();
        overviewPreloading = true;
        overviewPhase = "preparing";
        if (overviewLoader.status === Loader.Ready) {
            beginOverviewOpening();
        }
    }

    function closeOverview() {
        if (compositorIsNiri)
            return;
        if (!overviewMounted) return;
        if (overviewLoader.status === Loader.Ready)
            overviewUnloadGraceTimer.restart();
        overviewRevealTimer.stop();
        overviewPreloadExpireTimer.stop();
        islandContainer.restoreRestingCapsule(true);
        overviewPreloading = false;
        overviewPhase = "closed";
    }

    function closeOverviewEverywhere() {
        if (shellRootController && shellRootController.closeOverviewAll) {
            shellRootController.closeOverviewAll();
            return;
        }

        closeOverview();
    }

    function setConnectivityDetailVisible(kind, open) {
        const nextOpen = !!open;

        if (kind === "wifi") {
            if (nextOpen) {
                wifiConnectivityDetailCleanupTimer.stop();
                wifiConnectivityDetailMounted = true;
                wifiConnectivityDetailOpen = true;
            } else {
                if (!wifiConnectivityDetailMounted && !wifiConnectivityDetailOpen)
                    return;
                wifiConnectivityDetailOpen = false;
                wifiConnectivityDetailCleanupTimer.restart();
            }
            return;
        }

        if (kind === "power") {
            if (nextOpen) {
                powerConnectivityDetailCleanupTimer.stop();
                powerConnectivityDetailMounted = true;
                powerConnectivityDetailOpen = true;
            } else {
                if (!powerConnectivityDetailMounted && !powerConnectivityDetailOpen)
                    return;
                powerConnectivityDetailOpen = false;
                powerConnectivityDetailCleanupTimer.restart();
            }
            return;
        }

        if (kind === "bluetooth") {
            if (nextOpen) {
                bluetoothConnectivityDetailCleanupTimer.stop();
                bluetoothConnectivityDetailMounted = true;
                bluetoothConnectivityDetailOpen = true;
            } else {
                if (!bluetoothConnectivityDetailMounted && !bluetoothConnectivityDetailOpen)
                    return;
                bluetoothConnectivityDetailOpen = false;
                bluetoothConnectivityDetailCleanupTimer.restart();
            }
        }
    }

    function closeAllConnectivityDetails() {
        setConnectivityDetailVisible("wifi", false);
        setConnectivityDetailVisible("bluetooth", false);
        setConnectivityDetailVisible("power", false);
    }

    function openOverviewEverywhere() {
        if (shellRootController && shellRootController.openOverviewAll) {
            shellRootController.openOverviewAll();
            return;
        }

        openOverview();
    }

    function prepareOverviewEverywhere() {
        if (shellRootController && shellRootController.prepareOverviewAll) {
            shellRootController.prepareOverviewAll();
            return;
        }

        prepareOverview();
    }

    function cancelPreparedOverviewEverywhere() {
        if (shellRootController && shellRootController.cancelPreparedOverviewAll) {
            shellRootController.cancelPreparedOverviewAll();
            return;
        }

        cancelPreparedOverview();
    }

    function toggleOverviewEverywhere() {
        if (compositorIsNiri)
            return;

        if (shellRootController && shellRootController.toggleOverviewAll) {
            shellRootController.toggleOverviewAll();
            return;
        }

        if (overviewMounted)
            closeOverviewEverywhere();
        else
            openOverviewEverywhere();
    }

    function prewarmWallpaperCache() {
        overviewWallpaperCache.prewarm();
    }

    function handleWallpaperApplySucceeded(filePath) {
        wallpaperPickerActiveWallpaper = filePath;
        if (shellRootController && shellRootController.refreshOverviewWallpaperCaches)
            shellRootController.refreshOverviewWallpaperCaches(filePath);
        else
            prewarmWallpaperCache();
    }

    function showNotification(appName, summary, body) {
        islandContainer.showNotificationCapsule(appName, summary, body);
    }

    function showClockWindow() {
        islandContainer.showTimeCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }
    function showCustomInfoWindow() {
        islandContainer.showCustomCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }
    function showLyricsWindow() {
        islandContainer.showLyricsCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function swipeRightWindow() {
        if (islandContainer.restingState === "lyrics")
            islandContainer.showTimeCapsule();
        else if (islandContainer.restingState === "normal") {
            if (islandContainer.hasCustomLeftItems)
                islandContainer.showCustomCapsule();
            else
                islandContainer.showLyricsCapsule();
        }
        else
            islandContainer.showLyricsCapsule();

        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function swipeLeftWindow() {
        if (islandContainer.restingState === "custom")
            islandContainer.showTimeCapsule();
        else if (islandContainer.restingState === "normal")
            islandContainer.showLyricsCapsule();
        else if (islandContainer.hasCustomLeftItems)
            islandContainer.showCustomCapsule();
        else
            islandContainer.showTimeCapsule();

        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function togglePlayerWindow() {
        if (islandContainer.islandState === "expanded")
            islandContainer.smartRestoreState();
        else
            islandContainer.showExpandedPlayer(false);
    }

    function showTimerWindow() {
        islandContainer.showExpandedTimerPage();
    }

    function toggleControlCenterWindow() {
        if (islandContainer.islandState === "control_center" && !centerExit.running)
            islandContainer.smartRestoreState();
        else {
            islandContainer.showControlCenter();
            if (controlCenterLoader.item)
                controlCenterLoader.item.powerViewActive = false;
        }
    }

    function togglePowerMenuWindow() {
        if (islandContainer.islandState === "control_center"
                && controlCenterLoader.item
                && controlCenterLoader.item.powerViewActive) {
            islandContainer.smartRestoreState();
            return;
        }

        islandContainer.showControlCenter();
        if (controlCenterLoader.item)
            controlCenterLoader.item.powerViewActive = true;
    }

    function toggleNotificationCenterWindow() {
        if (islandContainer.islandState === "notification_center" && !centerExit.running)
            islandContainer.smartRestoreState();
        else
            islandContainer.showNotificationCenter();
    }

    function toggleWallpaperPickerWindow() {
        if (islandContainer.islandState === "wallpaper_picker")
            islandContainer.smartRestoreState();
        else
            islandContainer.showWallpaperPicker();
    }

    property string launcherSearchMode: "apps"
    property var launcherSearchEntries: []

    function toggleLauncherSearch(mode, entries) {
        const open = islandContainer.islandState === "application_launcher";
        if (open && launcherSearchMode === mode) {
            islandContainer.smartRestoreState();
            return;
        }
        launcherSearchEntries = entries;
        launcherSearchMode = mode;
        if (!open)
            islandContainer.showApplicationLauncher();
        focusApplicationLauncher();
    }

    function toggleApplicationLauncherWindow() {
        toggleLauncherSearch("apps", []);
    }

    function toggleFileShelfWindow() {
        if (islandContainer.islandState === "file_shelf")
            islandContainer.smartRestoreState();
        else
            islandContainer.showFileShelf(true);
    }

    function toggleClipboardWindow() {
        if (islandContainer.islandState === "clipboard")
            islandContainer.smartRestoreState();
        else
            islandContainer.showClipboard();
    }

    function showClipboardWindow() {
        islandContainer.showClipboard();
    }

    function closeClipboardWindow() {
        if (islandContainer.islandState === "clipboard")
            islandContainer.smartRestoreState();
    }

    function toggleWeatherWindow() {
        if (islandContainer.islandState === "weather")
            islandContainer.smartRestoreState();
        else
            islandContainer.showWeather();
    }

    function showWeatherWindow() {
        islandContainer.showWeather();
    }

    function closeWeatherWindow() {
        if (islandContainer.islandState === "weather")
            islandContainer.smartRestoreState();
    }

    function toggleCalendarWindow() {
        if (islandContainer.islandState === "calendar")
            islandContainer.smartRestoreState();
        else
            islandContainer.showCalendar();
    }

    function showCalendarWindow() {
        islandContainer.showCalendar();
    }

    function closeCalendarWindow() {
        if (islandContainer.islandState === "calendar")
            islandContainer.smartRestoreState();
    }

    onOverviewVisibleChanged: {
        if (overviewVisible && monitorFocused) overviewFocusTimer.restart();
        if (overviewVisible)
            showAutoHiddenIsland("state");
        else
            scheduleAutoHide();
    }
    onConnectivityPromptActiveChanged: {
        if (connectivityPromptActive && monitorFocused)
            connectivityPromptFocusTimer.restart();
        if (connectivityPromptActive)
            showAutoHiddenIsland("state");
        else
            scheduleAutoHide();
    }
    onAutoHideEnabledChanged: {
        if (autoHideEnabled)
            scheduleAutoHide();
        else
            showAutoHiddenIsland("manual");
    }
    onAutoHideCanHideNowChanged: {
        if (autoHideCanHideNow)
            scheduleAutoHide();
        else
            showAutoHiddenIsland("state");
    }
    onOverviewVisualReadyChanged: {
        if (overviewVisualReady) beginOverviewOpening();
    }
    onOverviewContentVisibleChanged: {
        if (overviewContentVisible && monitorFocused)
            overviewFocusTimer.restart();
    }
    onMonitorFocusedChanged: {
        if (overviewVisible && monitorFocused) overviewFocusTimer.restart();
        if (connectivityPromptActive && monitorFocused) connectivityPromptFocusTimer.restart();
    }

    Timer {
        id: overviewFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.focusOverview()
    }

    Timer {
        id: connectivityPromptFocusTimer
        interval: 0
        repeat: false
        onTriggered: islandContainer.forceActiveFocus()
    }

    Timer {
        id: expandedPlayerFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.focusExpandedPlayer()
    }

    Timer {
        id: windowShrinkTimer
        interval: 1000
        repeat: false
        onTriggered: root.retainedWindowHeight = root.requestedWindowHeight
    }

    Timer {
        id: autoHideHideTimer
        interval: userConfig.durations.islandAutoHideDelayMs
        repeat: false
        onTriggered: root.hideAutoHiddenIsland(false)
    }

    function focusWallpaperPicker() {
        islandContainer.forceActiveFocus();
        if (wallpaperPickerLoader.item && wallpaperPickerLoader.item.grabKeyboardFocus)
            wallpaperPickerLoader.item.grabKeyboardFocus();
    }

    function focusOverview() {
        islandContainer.forceActiveFocus();
        const view = islandContainer.overviewView;
        if (view && view.grabKeyboardFocus)
            view.grabKeyboardFocus();
    }

    function focusExpandedPlayer() {
        if (root.sourcePlayerExpanded) return;
        islandContainer.requestExpandedPlayerKeyboardFocus();
        if (expandedPlayerLoader.item && expandedPlayerLoader.item.grabKeyboardFocus)
            expandedPlayerLoader.item.grabKeyboardFocus();
    }

    function focusApplicationLauncher() {
        islandContainer.forceActiveFocus();
        if (applicationLauncherLoader.item && applicationLauncherLoader.item.grabKeyboardFocus)
            applicationLauncherLoader.item.grabKeyboardFocus();
    }

    function focusFileShelf() {
        islandContainer.forceActiveFocus();
        if (fileShelfLoader.item && fileShelfLoader.item.grabKeyboardFocus)
            fileShelfLoader.item.grabKeyboardFocus();
    }

    function focusClipboard() {
        islandContainer.forceActiveFocus();
        if (clipboardLoader.item && clipboardLoader.item.grabKeyboardFocus)
            clipboardLoader.item.grabKeyboardFocus();
    }

    function dragCarriesFiles(dragEvent) {
        if (!dragEvent)
            return false;
        if (dragEvent.hasUrls)
            return true;

        const formats = dragEvent.formats || [];
        return formats.indexOf("text/uri-list") >= 0
            || formats.indexOf("x-special/gnome-copied-files") >= 0;
    }

    function addFilesFromDrop(dropEvent) {
        if (!dropEvent)
            return 0;

        let added = 0;
        if (dropEvent.hasUrls)
            added += FileShelf.addUrls(dropEvent.urls);

        const formats = dropEvent.formats || [];
        if (added === 0 && formats.indexOf("text/uri-list") >= 0)
            added += FileShelf.addUriList(dropEvent.getDataAsString("text/uri-list"));
        if (added === 0 && formats.indexOf("x-special/gnome-copied-files") >= 0)
            added += FileShelf.addUriList(dropEvent.getDataAsString("x-special/gnome-copied-files"));
        return added;
    }

    Timer {
        id: overviewRevealTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (root.overviewPhase === "opening") root.overviewPhase = "open";
        }
    }

    Timer {
        id: overviewPreloadExpireTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (root.overviewPhase === "closed")
                root.overviewPreloading = false;
        }
    }

    Timer {
        id: overviewUnloadGraceTimer
        interval: 260
        repeat: false
    }

    Timer {
        id: wifiConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.wifiConnectivityDetailMounted = false
    }

    Timer {
        id: bluetoothConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.bluetoothConnectivityDetailMounted = false
    }

    Timer {
        id: powerConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.powerConnectivityDetailMounted = false
    }

    OverviewWallpaperCacheController {
        id: overviewWallpaperCache

        active: root.overviewLoaderActive
        wallpaperPath: userConfig.wallpaperCustomCommandEnabled === true && root.wallpaperPickerActiveWallpaper !== ""
            ? root.wallpaperPickerActiveWallpaper
            : userConfig.wallpaperPath
        hyprMonitor: root.hyprMonitor
        screenObject: root.screen
    }

    IslandClock {
        id: timeObj
        clockFormat: userConfig.clockFormat
    }

    // --- 灵动岛主容器与全局状态 ---
    FocusScope {
        id: islandContainer
        anchors.fill: parent
        focus: (root.activityLayerOpen && activities.detailed && !root.sourceActivityExpanded)
            || controlCenterLayerVisible
            || notificationCenterLayerVisible
            || wallpaperPickerLayerVisible
            || applicationLauncherLayerVisible
            || fileShelfLayerVisible
            || clipboardLayerVisible
            || weatherLayerVisible
            || calendarLayerVisible
            || expandedPlayerKeyboardFocusRequested
            || (root.monitorFocused && (root.overviewVisible || root.connectivityPromptActive))

        property string islandState: "normal"
        onIslandStateChanged: {
            centerExit.stop()
            centerExitProgress = 0
            clickMerge.cancel()
        }
        property real centerExitProgress: 0
        NumberAnimation {
            id: centerExit
            target: islandContainer
            property: "centerExitProgress"
            from: 0; to: 1; duration: 170
            easing.type: Easing.InCubic
            onFinished: islandContainer.restoreRestingCapsule()
        }
        property string splitIcon: root.defaultSplitIcon
        property real osdProgress: -1.0
        property string levelOsdKind: ""
        readonly property bool levelOsdVisible: islandState === "split" && levelOsdKind !== ""
        property bool osdProgressAnimationEnabled: true
        property string osdCustomText: ""
        property int currentWs: root.currentMonitorWorkspaceId > 0 ? root.currentMonitorWorkspaceId : 1
        readonly property int batteryCapacity: systemState.batteryCapacity
        readonly property bool isCharging: systemState.isCharging
        readonly property real currentVolume: systemState.currentVolume
        readonly property bool isMuted: systemState.isMuted
        readonly property real currentBrightness: systemState.currentBrightness
        readonly property real currentCpuUsage: systemState.currentCpuUsage
        readonly property real currentRamUsage: systemState.currentRamUsage
        property string notificationAppName: ""
        property string notificationSummary: ""
        property string notificationBody: ""
        property bool notificationExpanded: false
        property bool isEmergencyAlert: false
        property real customCapsuleWidth: userConfig.islandWidth
        property real lyricsCapsuleWidth: userConfig.islandWidth
        property string transientCapsuleIcon: ""
        property real transientCapsuleProgress: -1.0
        property string transientCapsuleText: ""
        property string restingState: normalizeRestingState(userConfig.dynamicIslandRestingState)
        property string workspaceOriginSide: "none"
        property string splitOriginSide: "none"
        property var bluetoothExpandedDevice: null
        property var notificationHistoryModel: ListModel {}
        readonly property var cavaLevels: systemState.cavaLevels
        property real swipeTransitionProgress: 0
        property bool expandedByPlayerAutoOpen: false
        property bool sideSwipeSettling: false
        property bool hoverExpandedActive: false
        property bool expandedPlayerKeyboardFocusRequested: false
        property bool openTimerPageWhenExpanded: false
        property int timerSelectedHours: 0
        property int timerSelectedMinutes: 5
        property int timerTotalSeconds: 300
        property int timerRemainingSeconds: 0
        property bool timerRunning: false
        property bool timerActive: false
        property bool timerCompletionAnimating: false
        property real timerCompletionPulse: 0
        property real timerCompletionFlash: 0
        property bool fileShelfOpenedManually: false
        readonly property int defaultAutoHideInterval: userConfig.durations.transientCapsuleDurationMs
        readonly property int notificationAutoHideInterval: 4200
        readonly property int bluetoothExpandedAutoHideInterval: userConfig.durations.bluetoothDetailDurationMs
        readonly property int swipeAnimationDuration: 220
        readonly property bool showsMediaInNormal: restingState === "lyrics"
            || (restingState === "normal" && !!currentTrack)
            || (restingState === "custom" && !hasCustomLeftItems && !!currentTrack)
        readonly property bool fileShelfLayerInteractive: !root.overviewVisible
            && (islandState === "file_shelf" || islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool clipboardLayerInteractive: !root.overviewVisible
            && (islandState === "clipboard" || islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool weatherLayerInteractive: !root.overviewVisible
            && (islandState === "weather" || islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool calendarLayerInteractive: !root.overviewVisible
            && (islandState === "calendar" || islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool fileShelfOverlayActive: fileShelfLayerInteractive && fileShelfLoader.item && fileShelfLoader.item.hasVisibleCards
        readonly property bool fileShelfAcceptingDrop: islandFileDropArea.containsDrag
            && !root.overviewVisible
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property real timerProgress: timerActive && timerTotalSeconds > 0
            ? Math.max(0, Math.min(1, timerRemainingSeconds / timerTotalSeconds))
            : 0
        readonly property bool timerBubbleWanted: timerCompletionAnimating
            && !root.overviewVisible
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool fileShelfBubbleWanted: FileShelf.count > 0
            && !root.overviewVisible
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool fileShelfCanAutoOpen: !root.overviewVisible
            && (islandState === "normal" || islandState === "lyrics" || islandState === "custom")
        readonly property bool blocksTransientSplit: islandState === "expanded"
            || islandState === "bluetooth_expanded"
            || islandState === "control_center"
            || islandState === "notification"
            || islandState === "wallpaper_picker"
            || islandState === "application_launcher"
            || islandState === "file_shelf"
            || islandState === "clipboard"
            || islandState === "weather"
            || islandState === "calendar"
        readonly property bool splitShowsProgress: islandState === "split" && osdProgress >= 0
        readonly property bool splitShowsText: islandState === "split" && osdProgress < 0 && osdCustomText !== ""
        readonly property bool splitShowsIconOnly: islandState === "split" && osdProgress < 0 && osdCustomText === ""
        readonly property bool splitUsesExtendedLayout: splitShowsProgress || splitShowsText
        readonly property real splitCapsuleWidth: levelOsdVisible ? 300 : splitShowsProgress ? 248 : (splitShowsText ? 220 : userConfig.islandWidth)
        readonly property bool canShowSideSwipe: islandState === "normal"
            || islandState === "custom"
            || islandState === "lyrics"
            || (islandState === "long_capsule" && workspaceOriginSide === "none")
        readonly property real rightSwipeProgress: Math.max(0, swipeTransitionProgress)
        readonly property var customLeftItems: systemState.customLeftItems
        readonly property bool hasCustomLeftItems: systemState.hasCustomLeftItems
        readonly property bool customSwipeVisible: !root.overviewVisible
            && hasCustomLeftItems
            && (
                capsuleMouseArea.sideSwipeInteractive
                ? swipeTransitionProgress < 0
                : (
                    islandState === "custom"
                    || (islandState === "normal" && swipeTransitionProgress < 0)
                    || (islandState === "split" && splitOriginSide === "left")
                    || (islandState === "long_capsule"
                        && (workspaceOriginSide === "left" || swipeTransitionProgress < 0))
                )
            )
        readonly property bool lyricsSwipeVisible: !root.overviewVisible && (
            capsuleMouseArea.sideSwipeInteractive
            ? swipeTransitionProgress >= 0
            : (
                islandState === "lyrics"
                || (islandState === "normal" && swipeTransitionProgress >= 0)
                || (islandState === "split" && splitOriginSide === "right")
                || (islandState === "long_capsule"
                    && (workspaceOriginSide === "right" || swipeTransitionProgress > 0))
            )
        )
        readonly property bool expandedLayerVisible: !root.overviewVisible && islandState === "expanded"
        readonly property bool bluetoothExpandedLayerVisible: !root.overviewVisible && islandState === "bluetooth_expanded"
        readonly property bool notificationLayerVisible: !root.overviewVisible && islandState === "notification"
        readonly property bool controlCenterLayerVisible: !root.overviewVisible && islandState === "control_center"
        readonly property bool notificationCenterLayerVisible: !root.overviewVisible && islandState === "notification_center"
        readonly property bool wallpaperPickerLayerVisible: !root.overviewVisible && islandState === "wallpaper_picker"
        readonly property bool applicationLauncherLayerVisible: !root.overviewVisible && islandState === "application_launcher"
        readonly property bool fileShelfLayerVisible: !root.overviewVisible && islandState === "file_shelf"
        readonly property bool clipboardLayerVisible: !root.overviewVisible && islandState === "clipboard"
        readonly property bool weatherLayerVisible: !root.overviewVisible && islandState === "weather"
        readonly property bool calendarLayerVisible: !root.overviewVisible && islandState === "calendar"
        readonly property var activePlayer: mediaController.activePlayer
        readonly property string lyricsDisplayText: mediaController.displayText
        readonly property string currentTrack: mediaController.currentTrack
        readonly property string currentArtist: mediaController.currentArtist
        readonly property string currentArtUrl: mediaController.currentArtUrl
        readonly property real trackProgress: mediaController.trackProgress
        readonly property string timePlayed: mediaController.timePlayed
        readonly property string timeTotal: mediaController.timeTotal
        readonly property bool screenRecordingActive: root.screenRecordingActive
        readonly property var bluetoothDevices: bluetoothConnectionTracker.devices
        readonly property var overviewView: overviewLoader.item && overviewLoader.item.overviewView
            ? overviewLoader.item.overviewView
            : null

        onExpandedLayerVisibleChanged: {
            if (expandedLayerVisible) {
                if (!root.sourcePlayerExpanded) requestExpandedPlayerKeyboardFocus();
            } else {
                expandedPlayerKeyboardFocusRequested = false;
                if (activities.activatedSourceId === "media") activities.activatedSourceId = "";
            }
        }

        onControlCenterLayerVisibleChanged: {
            if (!controlCenterLayerVisible) {
                // The shells belong to this window, so close them even if
                // clearing a provider's prompts or backend messages fails.
                root.closeAllConnectivityDetails();
                if (controlCenterLoader.item)
                    controlCenterLoader.item.closeConnectivityPanels();
            }
        }

        onFileShelfLayerVisibleChanged: {
            if (!fileShelfLayerVisible)
                fileShelfOpenedManually = false;
        }

        onCustomLeftItemsChanged: {
            if (restingState === "custom" && !hasCustomLeftItems) {
                restingState = "normal";

                if (islandState === "custom"
                        || (islandState === "split" && splitOriginSide === "left")
                        || (islandState === "long_capsule" && workspaceOriginSide === "left")) {
                    restoreRestingCapsule(true);
                } else {
                    applyRestingVisuals();
                }
            } else if (restingState === "custom") {
                syncCustomCapsuleWidth();
            }
        }

        IslandMprisController {
            id: mediaController

            expanded: islandContainer.islandState === "expanded"
            clientId: "island-mpris-" + root.screenOutputName
        }

        BluetoothConnectionTracker {
            id: bluetoothConnectionTracker

            onAdapterChanged: islandContainer.bluetoothExpandedDevice = null

            onNewConnection: function(device) {
                islandContainer.showBluetoothExpanded(device);
            }
        }

        IslandSystemState {
            id: systemState

            weatherService: root.weatherService
            configuredLeftSwipeItems: userConfig.dynamicIslandLeftSwipeItems
            timeText: timeObj.currentTime
            dateText: timeObj.currentDateLabel
            currentTrack: islandContainer.currentTrack
            currentArtUrl: islandContainer.currentArtUrl
            currentWorkspace: islandContainer.currentWs
            customSwipeActive: customSwipeLoader.active
            statsVisible: customSwipeLoader.active && root.autoHideProgress > 0.001
            lyricsCavaActive: islandContainer.lyricsSwipeVisible
                && islandContainer.rightSwipeProgress > 0.001

            onLevelRequested: function(kind, progress) {
                islandContainer.showTransientCapsule("", progress, "", kind);
            }

            onTransientRequested: function(icon, progress, text) {
                islandContainer.showTransientCapsule(icon, progress, text);
            }
        }

        CompositorWorkspaceTracker {
            id: workspaceTracker

            compositor: CompositorBackend.compositor
            hyprMonitor: root.hyprMonitor
            hyprMonitorName: root.hyprMonitorName
            outputName: root.compositorOutputName
            monitorFocused: root.monitorFocused

            onWorkspaceSynced: function(workspaceId) {
                islandContainer.currentWs = workspaceId;
            }

            onWorkspaceActivated: function(workspaceId) {
                if(userConfig.islandShowWorkspaceOnAutoHide){
                    root.showAutoHiddenIsland();
                }

                islandContainer.showWorkspaceCapsule(workspaceId);
            }
        }
        Connections {
            target: CompositorBackend
            function onApplicationOrderChanged(outputName, before, after) {
                if (outputName === root.compositorOutputName)
                    islandContainer.showApplicationCapsule(before, after);
            }
        }

        Behavior on osdProgress {
            enabled: islandContainer.osdProgressAnimationEnabled

            SmoothedAnimation { velocity: 1.2; duration: 180; easing.type: Easing.InOutQuad }
        }
        Behavior on swipeTransitionProgress {
            NumberAnimation {
                duration: capsuleMouseArea.sideSwipeInteractive ? 0 : islandContainer.swipeAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (root.activityLayerOpen && activities.detailed) {
                    activities.closeDetails();
                    event.accepted = true;
                    return;
                }

                if (root.overviewVisible) {
                    root.closeOverviewEverywhere();
                    event.accepted = true;
                    return;
                }

                if (islandContainer.clipboardLayerVisible) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                    return;
                }

                if (islandContainer.weatherLayerVisible) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                    return;
                }

                if (islandContainer.calendarLayerVisible) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                    return;
                }

                if (islandContainer.expandedLayerVisible) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                    return;
                }

                if (islandContainer.controlCenterLayerVisible) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                    return;
                }

                if (islandContainer.notificationCenterLayerVisible) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                    return;
                }
            }

            if (!root.overviewVisible) return;

            const view = islandContainer.overviewView;
            if (event.key === Qt.Key_H) {
                if (view)
                    view.focusAdjacentWorkspace(0, -1);
                event.accepted = true;
            } else if (event.key === Qt.Key_J) {
                if (view)
                    view.focusAdjacentWorkspace(1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_K) {
                if (view)
                    view.focusAdjacentWorkspace(-1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_L) {
                if (view)
                    view.focusAdjacentWorkspace(0, 1);
                event.accepted = true;
            } else if ((event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) || event.key === Qt.Key_Backtab) {
                if (root.hyprlandIntegration)
                    root.hyprlandIntegration.focusWorkspace("r-1");
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                if (root.hyprlandIntegration)
                    root.hyprlandIntegration.focusWorkspace("r+1");
                event.accepted = true;
            }
        }

        function handleConfiguredClickAction(actionName) {
            switch (actionName) {
            case "":
            case "none":
                return;
            case "toggleExpandedPlayer":
                if (islandState === "expanded") {
                    autoHideTimer.stop();
                    smartRestoreState();
                } else {
                    showExpandedPlayer(false);
                }
                return;
            case "openExpandedPlayer":
                showExpandedPlayer(false);
                return;
            case "closeExpandedPlayer":
                if (islandState === "expanded")
                    smartRestoreState();
                return;
            case "toggleNotificationCenter":
                if (islandState === "notification_center")
                    smartRestoreState();
                else
                    showNotificationCenter();
                return;
            case "openNotificationCenter":
                showNotificationCenter();
                return;
            case "closeNotificationCenter":
                if (islandState === "notification_center")
                    smartRestoreState();
                return;
            case "toggleControlCenter":
                if (islandState === "control_center")
                    smartRestoreState();
                else
                    showControlCenter();
                return;
            case "openControlCenter":
                showControlCenter();
                return;
            case "closeControlCenter":
                if (islandState === "control_center")
                    smartRestoreState();
                return;
            case "toggleOverview":
                root.toggleOverviewEverywhere();
                return;
            case "openOverview":
                root.openOverviewEverywhere();
                return;
            case "closeOverview":
                root.closeOverviewEverywhere();
                return;
            case "toggleLyrics":
                if (restingState === "lyrics")
                    showTimeCapsule();
                else
                    showLyricsCapsule();
                return;
            case "showLyrics":
                showLyricsCapsule();
                return;
            case "showTime":
                showTimeCapsule();
                return;
            case "restoreRestingCapsule":
                smartRestoreState();
                return;
            case "toggleClipboard":
                if (islandState === "clipboard")
                    smartRestoreState();
                else
                    showClipboard();
                return;
            case "openClipboard":
            case "showClipboard":
                showClipboard();
                return;
            case "closeClipboard":
                if (islandState === "clipboard")
                    smartRestoreState();
                return;
            case "toggleWeather":
                if (islandState === "weather")
                    smartRestoreState();
                else
                    showWeather();
                return;
            case "openWeather":
            case "showWeather":
                showWeather();
                return;
            case "closeWeather":
                if (islandState === "weather")
                    smartRestoreState();
                return;
            case "toggleCalendar":
                if (islandState === "calendar")
                    smartRestoreState();
                else
                    showCalendar();
                return;
            case "openCalendar":
            case "showCalendar":
                showCalendar();
                return;
            case "closeCalendar":
                if (islandState === "calendar")
                    smartRestoreState();
                return;
            default:
            }
        }

        function clamp01(value) {
            return Math.max(0, Math.min(1, value));
        }

        function normalizeRestingState(nextState) {
            if (nextState === "lyrics") return "lyrics";
            if (nextState === "custom" && hasCustomLeftItems) return "custom";
            return "normal";
        }

        function restingStateProgress(nextState) {
            switch (normalizeRestingState(nextState)) {
            case "custom":
                return -1;
            case "lyrics":
                return 1;
            default:
                return 0;
            }
        }

        function restingStateSide(nextState) {
            switch (normalizeRestingState(nextState)) {
            case "custom":
                return "left";
            case "lyrics":
                return "right";
            default:
                return "none";
            }
        }

        function swipeRestProgressForState() {
            switch (islandState) {
            case "custom":
                return -1;
            case "lyrics":
                return 1;
            default:
                return 0;
            }
        }

        function currentTransientOriginSide() {
            switch (islandState) {
            case "custom":
                return "left";
            case "lyrics":
                return "right";
            case "long_capsule":
                return workspaceOriginSide;
            case "split":
                return splitOriginSide;
            default:
                return "none";
            }
        }

        function setOsdProgress(nextProgress, animate) {
            osdProgressAnimationReset.stop();
            osdProgressAnimationEnabled = animate;
            osdProgress = nextProgress;
            if (!animate) osdProgressAnimationReset.restart();
        }

        function abortSideTransientMode() {
            sideTransientRestoreTimer.stop();
            workspaceOriginSide = "none";
            splitOriginSide = "none";
        }

        function clearTransientCapsule() {
            levelOsdKind = "";
            setOsdProgress(-1.0, false);
            osdCustomText = "";
            notificationAppName = "";
            notificationSummary = "";
            notificationBody = "";
            notificationExpanded = false;
            bluetoothExpandedDevice = null;
        }

        function cleanNotificationText(text) {
            return String(text === undefined || text === null ? "" : text)
                .replace(/<[^>]*>/g, " ")
                .replace(/&nbsp;/g, " ")
                .replace(/&amp;/g, "&")
                .replace(/&quot;/g, "\"")
                .replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">")
                .replace(/\s+/g, " ")
                .trim();
        }

        function prepareRestingCapsuleGeometry() {
            if (restingState === "custom")
                syncCustomCapsuleWidth();
            if (restingState === "lyrics")
                syncLyricsCapsuleWidth();
        }

        function applyRestingVisuals() {
            prepareRestingCapsuleGeometry();
            swipeTransitionProgress = restingStateProgress(restingState);
        }

        function sideSwipeRestProgressForProgress(progressValue) {
            if (progressValue <= -0.5) return -1;
            if (progressValue >= 0.5) return 1;
            return 0;
        }

        function sideSwipeRestWidthForProgress(progressValue) {
            if (progressValue <= -0.5) return customCapsuleWidth;
            if (progressValue >= 0.5) return lyricsCapsuleWidth;
            return userConfig.islandWidth;
        }

        function customSideSwipeDragDistance() {
            const view = customSwipeLoader.item;
            if (view && view.dragDistance > 0) return view.dragDistance;
            return Math.max(userConfig.islandWidth, customCapsuleWidth + 4);
        }

        function lyricsSideSwipeDragDistance() {
            const view = lyricsSwipeLoader.item;
            if (view && view.dragDistance > 0) return view.dragDistance;
            return Math.max(userConfig.islandWidth, lyricsCapsuleWidth + 2);
        }

        function sideSwipeDragDistanceForDirection(direction) {
            if (direction === "left") return customSideSwipeDragDistance();
            if (direction === "right") return lyricsSideSwipeDragDistance();
            return userConfig.islandWidth;
        }

        function advanceSideSwipeProgress(currentProgress, deltaX) {
            const minProgress = hasCustomLeftItems ? -1 : 0;
            let nextProgress = Math.max(minProgress, Math.min(1, currentProgress));
            let remainingDelta = deltaX;

            if (remainingDelta > 0) {
                if (nextProgress < 0) {
                    const leftDistance = Math.max(1, sideSwipeDragDistanceForDirection("left"));
                    const progressToCenter = Math.min(-nextProgress, remainingDelta / leftDistance);
                    nextProgress += progressToCenter;
                    remainingDelta -= progressToCenter * leftDistance;
                }

                if (remainingDelta > 0 && nextProgress < 1) {
                    const rightDistance = Math.max(1, sideSwipeDragDistanceForDirection("right"));
                    nextProgress = Math.min(1, nextProgress + remainingDelta / rightDistance);
                }
            } else if (remainingDelta < 0) {
                if (nextProgress > 0) {
                    const rightDistance = Math.max(1, sideSwipeDragDistanceForDirection("right"));
                    const progressToCenter = Math.min(nextProgress, -remainingDelta / rightDistance);
                    nextProgress -= progressToCenter;
                    remainingDelta += progressToCenter * rightDistance;
                }

                if (remainingDelta < 0 && nextProgress > minProgress) {
                    const leftDistance = Math.max(1, sideSwipeDragDistanceForDirection("left"));
                    nextProgress = Math.max(minProgress, nextProgress + remainingDelta / leftDistance);
                }
            }

            return Math.max(minProgress, Math.min(1, nextProgress));
        }

        function resolveSideSwipeSettle(startProgress, finalProgress) {
            let settleAction = "";
            let settleProgress = sideSwipeRestProgressForProgress(startProgress);
            let settleWidth = sideSwipeRestWidthForProgress(startProgress);

            if (finalProgress >= 0.56) {
                settleAction = "lyrics";
                settleProgress = 1;
                settleWidth = lyricsCapsuleWidth;
            } else if (hasCustomLeftItems && finalProgress <= -0.56) {
                settleAction = "custom";
                settleProgress = -1;
                settleWidth = customCapsuleWidth;
            } else if (startProgress <= -0.5) {
                if (finalProgress >= -0.44) {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = userConfig.islandWidth;
                }
            } else if (startProgress >= 0.5) {
                if (finalProgress <= 0.44) {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = userConfig.islandWidth;
                }
            } else {
                settleAction = "time";
                settleProgress = 0;
                settleWidth = userConfig.islandWidth;
            }

            return {
                action: settleAction,
                progress: settleProgress,
                width: settleWidth
            };
        }

        function beginSideSwipeSettle(targetWidth) {
            sideSwipeSettling = true;
            mainCapsule.displayedWidth = targetWidth;
            sideSwipeSettleReset.restart();
        }

        function cancelSideSwipeSettle() {
            sideSwipeSettleReset.stop();
            sideSwipeSettling = false;
        }

        function finishSideSwipeSettle() {
            sideSwipeSettling = false;
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
        }

        function restartAutoHideTimer(duration) {
            autoHideTimer.interval = duration === undefined ? defaultAutoHideInterval : duration;
            autoHideTimer.restart();
        }

        function stopAutoHideTimer() {
            autoHideTimer.stop();
            autoHideTimer.interval = defaultAutoHideInterval;
        }

        function requestExpandedPlayerKeyboardFocus() {
            const shouldGrabFocus = !expandedPlayerKeyboardFocusRequested;
            expandedPlayerKeyboardFocusRequested = true;
            if (shouldGrabFocus)
                expandedPlayerFocusTimer.restart();
        }

        function releaseExpandedPlayerKeyboardFocus() {
            expandedPlayerKeyboardFocusRequested = false;
        }

        function clampTimerInput(value, minValue, maxValue) {
            const parsed = parseInt(value, 10);
            if (isNaN(parsed)) return minValue;
            return Math.max(minValue, Math.min(maxValue, parsed));
        }

        function syncTimerDuration(hours, minutes) {
            cancelTimerCompletionAnimation();
            timerSelectedHours = clampTimerInput(hours, 0, 23);
            timerSelectedMinutes = clampTimerInput(minutes, 0, 59);
            timerTotalSeconds = timerSelectedHours * 3600 + timerSelectedMinutes * 60;
            timerRemainingSeconds = 0;
            timerRunning = false;
            timerActive = false;
        }

        function toggleTimer(hours, minutes) {
            if (timerCompletionAnimating)
                cancelTimerCompletionAnimation();

            if (timerRunning) {
                timerRunning = false;
                return;
            }

            if (!timerActive || timerRemainingSeconds <= 0) {
                syncTimerDuration(hours, minutes);
                timerRemainingSeconds = timerTotalSeconds;
                timerActive = timerRemainingSeconds > 0;
            }

            if (timerRemainingSeconds > 0)
                timerRunning = true;
        }

        function resetTimer() {
            cancelTimerCompletionAnimation();
            timerRemainingSeconds = 0;
            timerRunning = false;
            timerActive = false;
        }

        function startTimerCompletionAnimation() {
            timerCompletionPulse = 0;
            timerCompletionFlash = 0;
            timerCompletionAnimating = true;
        }

        function cancelTimerCompletionAnimation() {
            timerCompletionAnimating = false;
            timerCompletionPulse = 0;
            timerCompletionFlash = 0;
        }

        function showExpandedTimerPage() {
            openTimerPageWhenExpanded = true;
            showExpandedPlayer(false);
            if (expandedPlayerLoader.item && expandedPlayerLoader.item.openTimerPage) {
                expandedPlayerLoader.item.openTimerPage();
                openTimerPageWhenExpanded = false;
            }
        }

        function showTransientCapsule(icon, progress, customText, levelKind) {
            if (progress === undefined)    progress = -1.0;
            if (customText === undefined)  customText = "";

            if (root.overviewVisible || blocksTransientSplit) return;
            if (!levelKind && root.autoHideSuppressesTransientReveal) return;

            const nextProgress = progress >= 0 ? progress : -1.0;
            const animateProgress = islandState === "split" && osdProgress >= 0 && nextProgress >= 0;
            const animateFromSide = currentTransientOriginSide();

            abortSideTransientMode();
            levelOsdKind = levelKind || "";
            splitIcon = icon;
            osdCustomText = customText;
            setOsdProgress(nextProgress, animateProgress);
            splitOriginSide = animateFromSide;
            islandState = "split";
            swipeTransitionProgress = 0;
            restartAutoHideTimer();
        }

        function showNotificationCapsule(appName, summary, body) {
            if (root.activityHub) root.activityHub.send({op:"local", app:appName, title:summary, body:body});
        }

        function toggleNotificationExpansionIfNeeded() {
            if (islandState !== "notification" || !notificationLoader.item || !notificationLoader.item.hasOverflowContent)
                return false;

            if (notificationExpanded) {
                smartRestoreState();
                return true;
            }

            notificationExpanded = true;
            stopAutoHideTimer();
            return true;
        }

        function suppressCapsuleClick(cancelPreparedOverview) {
            if (cancelPreparedOverview === undefined) cancelPreparedOverview = false;
            if (cancelPreparedOverview && capsuleMouseArea.preparedOverviewOnPress) {
                root.cancelPreparedOverviewEverywhere();
                capsuleMouseArea.preparedOverviewOnPress = false;
            }
            capsuleMouseArea.suppressNextClick = true;
            swipeSuppressReset.restart();
        }

        function restoreRestingCapsule(forceImmediate) {
            if (forceImmediate === undefined) forceImmediate = false;
            const normalizedRestingState = normalizeRestingState(restingState);
            const targetSide = restingStateSide(normalizedRestingState);
            const shouldAnimateToSide = targetSide !== "none"
                && ((islandState === "long_capsule" && workspaceOriginSide === targetSide)
                    || (islandState === "split" && splitOriginSide === targetSide));

            if (!forceImmediate && shouldAnimateToSide) {
                expandedByPlayerAutoOpen = false;
                prepareRestingCapsuleGeometry();
                swipeTransitionProgress = restingStateProgress(normalizedRestingState);
                stopAutoHideTimer();
                sideTransientRestoreTimer.restart();
                return;
            }

            abortSideTransientMode();
            prepareRestingCapsuleGeometry();
            islandState = normalizedRestingState;
            clearTransientCapsule();
            applyRestingVisuals();
            expandedByPlayerAutoOpen = false;
            stopAutoHideTimer();
        }

        function setRestingState(nextState) {
            restingState = normalizeRestingState(nextState);
        }

        function smartRestoreState() {
            activities.closeDetails();
            if (root.centerOpen) {
                root.closeAllConnectivityDetails()
                if (!centerExit.running) centerExit.start()
                return
            }
            restoreRestingCapsule();
        }

        function showRestingCapsule(nextState) {
            setRestingState(nextState);
            restoreRestingCapsule();
            stopAutoHideTimer();
        }

        function showExpandedPlayer(autoOpened) {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "expanded";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            expandedByPlayerAutoOpen = autoOpened;
            if (autoOpened) restartAutoHideTimer();
            else stopAutoHideTimer();
        }

        function showBluetoothExpanded(device) {
            if (!device || root.overviewVisible || islandState === "control_center"
                    || islandState === "notification" || islandState === "file_shelf")
                return;

            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            bluetoothExpandedDevice = device;
            islandState = "bluetooth_expanded";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            expandedByPlayerAutoOpen = false;
            restartAutoHideTimer(bluetoothExpandedAutoHideInterval);
        }

        function showCenter(state) {
            centerExit.stop()
            centerExitProgress = 0
            cancelSideSwipeSettle()
            abortSideTransientMode()
            clearTransientCapsule()
            islandState = state
            mainCapsule.displayedWidth = sideSwipeRestWidthForProgress(restingStateProgress(restingState))
            stopAutoHideTimer()
        }

        function showControlCenter() { showCenter("control_center") }
        function showNotificationCenter() { showCenter("notification_center") }

        function showWallpaperPicker() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "wallpaper_picker";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showApplicationLauncher() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "application_launcher";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showFileShelf(manuallyOpened) {
            const manual = manuallyOpened === true;
            if (islandState === "file_shelf") {
                if (manual)
                    fileShelfOpenedManually = true;
                return;
            }

            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            fileShelfOpenedManually = manual;
            islandState = "file_shelf";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function closeAutoOpenedFileShelf() {
            if (islandState === "file_shelf" && !fileShelfOpenedManually)
                smartRestoreState();
        }

        function showClipboard() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "clipboard";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showWeather() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "weather";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showCalendar() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "calendar";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showCustomCapsule() {
            if (!hasCustomLeftItems) {
                showTimeCapsule();
                return;
            }

            systemState.refreshMissingValues();
            showRestingCapsule("custom");
        }

        function showLyricsCapsule() {
            showRestingCapsule("lyrics");
        }

        function showTimeCapsule() {
            showRestingCapsule("normal");
        }

        function showWorkspaceCapsule(wsId) {
            currentWs = wsId;

            if (root.sourceActivityExpanded || root.sourcePlayerExpanded) return;
            if (root.autoHideSuppressesTransientReveal) return;
            if (islandState === "control_center" || islandState === "notification") return;
            const animateFromSide = currentTransientOriginSide();
            clearTransientCapsule();
            sideTransientRestoreTimer.stop();
            workspaceOriginSide = animateFromSide;
            splitOriginSide = "none";
            islandState = "long_capsule";
            swipeTransitionProgress = 0;
            restartAutoHideTimer();
        }

        function showApplicationCapsule(before, after) {
            if (root.overviewVisible || blocksTransientSplit || islandState === "notification_center"
                    || activities.detailed || clickMerge.source || root.shellRootController?.sessionLocked)
                return;
            if (islandState !== "app_queue") {
                abortSideTransientMode();
                clearTransientCapsule();
                stopAutoHideTimer();
                islandState = "app_queue";
            }
            appIconQueue.enqueue(before, after);
        }

        Timer { id: autoHideTimer; interval: islandContainer.defaultAutoHideInterval; onTriggered: islandContainer.smartRestoreState() }
        Timer {
            id: islandTimerTick
            interval: 1000
            repeat: true
            running: islandContainer.timerRunning
            onTriggered: {
                const nextRemainingSeconds = Math.max(0, islandContainer.timerRemainingSeconds - 1);
                if (nextRemainingSeconds <= 0) {
                    islandContainer.startTimerCompletionAnimation();
                    islandContainer.timerRemainingSeconds = 0;
                    islandContainer.timerRunning = false;
                    islandContainer.timerActive = false;
                } else {
                    islandContainer.timerRemainingSeconds = nextRemainingSeconds;
                }
            }
        }
        Timer {
            id: osdProgressAnimationReset
            interval: 0
            onTriggered: islandContainer.osdProgressAnimationEnabled = true
        }
        Timer {
            id: sideTransientRestoreTimer
            interval: islandContainer.swipeAnimationDuration
            onTriggered: {
                islandContainer.workspaceOriginSide = "none";
                islandContainer.splitOriginSide = "none";
                islandContainer.prepareRestingCapsuleGeometry();
                islandContainer.islandState = islandContainer.normalizeRestingState(islandContainer.restingState);
                islandContainer.clearTransientCapsule();
                islandContainer.applyRestingVisuals();
                islandContainer.expandedByPlayerAutoOpen = false;
            }
        }
        Timer {
            id: sideSwipeSettleReset
            interval: mainCapsule.morphDuration
            onTriggered: islandContainer.finishSideSwipeSettle()
        }
        Timer {
            id: hoverExpandDelayTimer
            interval: 350
            repeat: false
            onTriggered: {
                if (!capsuleMouseArea.containsMouse) return;
                if (!root.hoverExpandEnabled) return;

                const current = islandContainer.islandState;
                const target = root.configuredHoverExpandAction === 2 ? "control_center" : "expanded";
                if (current === target) return;
                if (current !== "normal" && current !== "custom" && current !== "lyrics")
                    return;

                islandContainer.hoverExpandedActive = true;
                if (root.configuredHoverExpandAction === 2)
                    islandContainer.showControlCenter();
                else
                    islandContainer.showExpandedPlayer(false);
            }
        }
        Timer {
            id: hoverCollapseDelayTimer
            interval: 250
            repeat: false
            onTriggered: {
                if (capsuleMouseArea.containsMouse) return;
                if (!islandContainer.hoverExpandedActive) return;
                islandContainer.hoverExpandedActive = false;
                islandContainer.smartRestoreState();
            }
        }

        function syncCustomCapsuleWidth() {
            const view = customSwipeLoader.item;
            if (!view) return;
            customCapsuleWidth = Math.max(220, Math.min(root.width - 48, view.preferredWidth));
        }

        function syncLyricsCapsuleWidth() {
            const view = lyricsSwipeLoader.item;
            if (!view) return;
            lyricsCapsuleWidth = Math.max(220, Math.min(root.width - 48, view.preferredWidth));
        }

        // --- UI 渲染：灵动岛主干 ---
        IslandFrame {
            id: capsuleFrame
            pixelRatio: root.devicePixelRatio
            strokeWidth: root.centerOpen ? 4 : mainCapsule.roundedCapsule
                ? userConfig.islandFrameWidth : userConfig.islandExpandedFrameWidth
            surfaceRadius: mainCapsule.radius
            strokeColor: mainCapsule.outlineColor
            outset: true
            opacity: liquid.visible ? 0 : mainCapsule.opacity
            x: mainCapsule.x - extension
            y: mainCapsule.y - extension
            width: mainCapsule.width + extension * 2
            height: mainCapsule.height + extension * 2
            z: mainCapsule.z + 1
            transform: Scale {
                origin.x: capsuleFrame.width / 2
                origin.y: capsuleFrame.extension
                xScale: mainCapsule.revealWidthScale
                yScale: mainCapsule.revealHeightScale
            }
        }

        IslandSurface {
            id: mainCapsule
            frameWidth: 0
            // The material is drawn by the liquid contour during contact.
            // Diffuse only the disappearing foreground, leaving that contour sharp.
            layer.enabled: liquid.visible && liquid.chip && !liquid.app
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 8; blur: liquid.contact * 0.65 }
            pixelRatio: root.devicePixelRatio

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
            }
            z: 5
            property int morphDuration: 280
            readonly property bool notificationHistorySurface: islandContainer.islandState === "notification_center"
            property color outlineColor: root.overviewContentVisible
                ? root.overviewCapsuleBorderColor
                : roundedCapsule ? Qt.alpha(StyleTokens.surfaceBorder, StyleTokens.surfaceBorder.a * root.compactKeyline) : StyleTokens.surfaceBorder
            property real displayedWidth: root.centerOpen ? userConfig.islandWidth : baseTargetWidth
            readonly property real baseTargetWidth: {
                if (root.overviewVisible) return root.overviewCapsuleWidth;
                if (root.activityLayerOpen) return Math.min(root.width - 24, activities.detailed ? 392 : 246);
                if (islandContainer.islandState === "long_capsule" && workspaceLayerLoader.item?.showsWorkspaceDots)
                    return Math.min(root.width, workspaceLayerLoader.item.preferredWidth);
                if (sideTransientRestoreTimer.running) {
                    if (islandContainer.restingState === "lyrics"
                            && ((islandContainer.islandState === "split" && islandContainer.splitOriginSide === "right")
                                || (islandContainer.islandState === "long_capsule" && islandContainer.workspaceOriginSide === "right"))) {
                        return islandContainer.lyricsCapsuleWidth;
                    }

                    if (islandContainer.restingState === "custom"
                            && ((islandContainer.islandState === "split" && islandContainer.splitOriginSide === "left")
                                || (islandContainer.islandState === "long_capsule" && islandContainer.workspaceOriginSide === "left"))) {
                        return islandContainer.customCapsuleWidth;
                    }
                }

                switch (islandContainer.islandState) {
                case "split":
                    return islandContainer.splitCapsuleWidth;
                case "long_capsule":
                    return 220;
                case "app_queue":
                    return Math.min(root.width, appIconQueue.preferredWidth);
                case "custom":
                    return islandContainer.customCapsuleWidth;
                case "lyrics":
                    return islandContainer.lyricsCapsuleWidth;
                case "control_center":
                    return Math.min(420, root.width - root.centerInset * 2);
                case "notification_center":
                    return Math.min(410, root.width - root.centerInset * 2);
                case "wallpaper_picker":
                case "application_launcher":
                case "file_shelf":
                    return 1100;
                case "clipboard":
                    return 520;
                case "weather":
                    return 460;
                case "calendar":
                    return 420;
                case "expanded":
                case "bluetooth_expanded":
                    return 410;
                case "notification":
                    if (!notificationLoader.item) return 272;
                    return Math.max(
                        notificationLoader.item.minimumWidth,
                        Math.min(root.width - 48, notificationLoader.item.maximumWidth, notificationLoader.item.preferredWidth)
                    );
                default:
                    return userConfig.islandWidth;
                }
            }
            readonly property real panelTargetHeight: islandContainer.controlCenterLayerVisible
                ? (controlCenterLoader.item?.powerViewActive ? 150 : 320 + (controlCenterLoader.item?.controlCenterExtraHeight ?? 32))
                : (notificationCenterLoader.item?.contentHeight ?? 200)
            readonly property real targetHeight: {
                if (root.overviewVisible) return root.overviewCapsuleHeight;
                if (root.activityLayerOpen && activities.detailed) return activities.detailHeight;

                switch (islandContainer.islandState) {
                case "wallpaper_picker":
                case "application_launcher":
                case "file_shelf":
                    return 260;
                case "clipboard":
                    return clipboardLoader.item && clipboardLoader.item.imgFullPreview ? 400 : 350;
                case "weather":
                case "calendar":
                    return 340;
                case "expanded":
                case "bluetooth_expanded":
                    return 165;
                case "notification":
                    return notificationLoader.item
                        ? Math.max(56, notificationLoader.item.preferredHeight)
                        : 56;
                default:
                    return userConfig.islandHeight;
                }
            }
            readonly property bool roundedCapsule: !root.overviewVisible
                && !(root.activityLayerOpen && activities.detailed)
                && (["normal", "custom", "lyrics", "split", "long_capsule", "app_queue"].includes(islandContainer.islandState)
                    || (islandContainer.notificationLayerVisible && !islandContainer.notificationExpanded))
            readonly property real targetRadius: Math.min(
                roundedCapsule ? targetHeight / 2 : root.centerCornerRadius, width / 2, height / 2)
            function sideSwipeWidthForProgress(progressValue) {
                if (progressValue < 0)
                    return userConfig.islandWidth + (islandContainer.customCapsuleWidth - userConfig.islandWidth)
                        * islandContainer.clamp01(-progressValue);
                if (progressValue > 0)
                    return userConfig.islandWidth + (islandContainer.lyricsCapsuleWidth - userConfig.islandWidth)
                        * islandContainer.clamp01(progressValue);
                return userConfig.islandWidth;
            }
            readonly property real sideSwipePreviewWidth: mainCapsule.sideSwipeWidthForProgress(
                islandContainer.swipeTransitionProgress
            )
            tint: root.overviewContentVisible ? root.overviewCapsuleColor : StyleTokens.panel
            materialOpacity: liquid.visible ? 0 : root.materialOpacity
            // Keep the top edge fixed and grow out from a small capsule.
            readonly property real revealWidthScale: 1 - (1 - Math.min(1, 34 / Math.max(1, width)))
                * (1 - root.autoHideProgress)
            readonly property real revealHeightScale: 1 - (1 - Math.min(1, 16 / Math.max(1, height)))
                * (1 - root.autoHideProgress)
            y: root.capsuleTop - (root.centerOpen ? 12 * islandContainer.centerExitProgress : 0)
            x: !parent ? 0 : islandContainer.controlCenterLayerVisible ? Math.max(0, parent.width - width - root.centerInset)
                : islandContainer.notificationCenterLayerVisible ? root.centerInset
                : parent.width * userConfig.islandPositionX / 100 - width / 2
            clip: true
            width: root.snapToOutputPixel(root.centerOpen ? baseTargetWidth : displayedWidth)
            readonly property bool liquidContact: roundedCapsule && (liquid.clicked || liquid.app || liquid.chip)
            // Central geometry stays independent while this surface is docked at an edge.
            property real centralHeight: targetHeight
                + (liquidContact ? Math.min(3, targetHeight * 0.08) * liquid.contact : 0)
            property real panelHeight: root.centerOpen ? panelTargetHeight : 0
            Behavior on panelHeight {
                enabled: root.centerOpen && mainCapsule.panelHeight > 0 && !(controlCenterLoader.item?.batteryDrawerMoving)
                NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint }
            }
            height: root.snapToOutputPixel(root.centerOpen ? panelHeight : centralHeight)
            radius: targetRadius
            opacity: root.autoHideProgress * (root.centerOpen ? 1 - islandContainer.centerExitProgress : 1)
            enabled: !centerExit.running
            transform: Scale {
                origin.x: mainCapsule.width / 2
                origin.y: 0
                xScale: mainCapsule.revealWidthScale
                yScale: mainCapsule.revealHeightScale
            }

            onBaseTargetWidthChanged: {
                if (!root.centerOpen && !capsuleMouseArea.sideSwipeInteractive && !islandContainer.sideSwipeSettling)
                    displayedWidth = baseTargetWidth;
            }

            Behavior on displayedWidth  {
                NumberAnimation {
                    id: capsuleWidthAnimation
                    duration: root.centerOpen || capsuleMouseArea.sideSwipeInteractive || liquid.app ? 0 : mainCapsule.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on centralHeight {
                enabled: !root.centerOpen && !mainCapsule.liquidContact && !(controlCenterLoader.item && controlCenterLoader.item.batteryDrawerMoving)

                NumberAnimation {
                    id: capsuleHeightAnimation
                    duration: mainCapsule.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on radius { NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint } }
            Behavior on outlineColor { ColorAnimation { duration: 260; easing.type: Easing.InOutQuad } }

            antialiasing: true

            MouseArea {
                id: capsuleMouseArea
                anchors.fill: parent
                z: -1
                enabled: !root.overviewVisible && twoFingerTouchArea.touchPoints.length < 2
                acceptedButtons: root.dynamicIslandAcceptedButtons
                preventStealing: true
                hoverEnabled: root.hoverExpandEnabled || root.autoHideEnabled
                property real swipeStartX: 0
                property real swipeStartY: 0
                property real swipeStartProgress: 0
                property real swipeLastX: 0
                readonly property real sideSwipeVerticalTolerance: 24
                property bool swipeArmed: false
                property bool swipeMoved: false
                property bool sideSwipeInteractive: false
                property bool suppressNextClick: false
                property bool preparedOverviewOnPress: false

                Timer {
                    id: swipeSuppressReset
                    interval: 180
                    repeat: false
                    onTriggered: capsuleMouseArea.suppressNextClick = false
                }

                onEntered: {
                    if (root.autoHideEnabled) {
                        root.autoHidePointerInside = true;
                        root.showAutoHiddenIsland();
                    }
                    if (root.hoverExpandEnabled) {
                        hoverCollapseDelayTimer.stop();
                        hoverExpandDelayTimer.restart();
                    }
                }

                onExited: {
                    if (root.autoHideEnabled) {
                        root.autoHidePointerInside = false;
                        root.scheduleAutoHide();
                    }
                    if (root.hoverExpandEnabled)
                        hoverCollapseDelayTimer.restart();
                }

                onPressed: (mouse) => {
                    const mappedPoint = capsuleMouseArea.mapToItem(islandContainer, mouse.x, mouse.y);
                    swipeStartX = mappedPoint.x;
                    swipeStartY = mappedPoint.y;
                    islandContainer.cancelSideSwipeSettle();
                    swipeArmed = mouse.button === Qt.LeftButton
                        && islandContainer.canShowSideSwipe;
                    swipeStartProgress = islandContainer.swipeTransitionProgress;
                    swipeLastX = mappedPoint.x;
                    swipeMoved = false;
                    sideSwipeInteractive = swipeArmed;
                    islandContainer.swipeTransitionProgress = swipeStartProgress;

                    let pressedAction = "";
                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)) {
                        pressedAction = userConfig.dynamicIslandPrimaryAction;
                    } else if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandSecondaryButton)) {
                        pressedAction = userConfig.dynamicIslandSecondaryAction;
                    } else if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandMiddleButton)) {
                        pressedAction = userConfig.dynamicIslandMiddleAction;
                    }

                    if (mouse.button === Qt.LeftButton && islandContainer.islandState === "normal") return;
                    preparedOverviewOnPress = pressedAction === "openOverview"
                        || (pressedAction === "toggleOverview" && root.overviewPhase === "closed");
                    if (preparedOverviewOnPress)
                        root.prepareOverviewEverywhere();
                }

                onPositionChanged: (mouse) => {
                    if (!pressed || !swipeArmed || suppressNextClick || twoFingerTouchArea.touchPoints.length >= 2) return;

                    const mappedPoint = capsuleMouseArea.mapToItem(islandContainer, mouse.x, mouse.y);
                    const deltaX = mappedPoint.x - swipeLastX;
                    const deltaY = Math.abs(mappedPoint.y - swipeStartY);
                    const adjustedDeltaX = deltaY < sideSwipeVerticalTolerance ? deltaX : 0;
                    const nextProgress = islandContainer.advanceSideSwipeProgress(
                        islandContainer.swipeTransitionProgress,
                        adjustedDeltaX
                    );

                    swipeMoved = swipeMoved || Math.abs(nextProgress - swipeStartProgress) > 0.03 || deltaY > 6;
                    swipeLastX = mappedPoint.x;
                    islandContainer.swipeTransitionProgress = nextProgress;
                    mainCapsule.displayedWidth = mainCapsule.sideSwipePreviewWidth;
                }

                onReleased: {
                    if (swipeMoved) {
                        if (preparedOverviewOnPress)
                            root.cancelPreparedOverviewEverywhere();
                        preparedOverviewOnPress = false;
                        suppressNextClick = true;
                        swipeSuppressReset.restart();
                    }
                    let settleResult = {
                        action: "",
                        progress: islandContainer.sideSwipeRestProgressForProgress(swipeStartProgress),
                        width: islandContainer.sideSwipeRestWidthForProgress(swipeStartProgress)
                    };

                    if (swipeArmed)
                        settleResult = islandContainer.resolveSideSwipeSettle(
                            swipeStartProgress,
                            islandContainer.swipeTransitionProgress
                        );

                    sideSwipeInteractive = false;

                    if (swipeArmed)
                        islandContainer.beginSideSwipeSettle(settleResult.width);
                    else
                        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;

                    if (swipeArmed) {
                        switch (settleResult.action) {
                        case "time":
                            islandContainer.showTimeCapsule();
                            break;
                        case "custom":
                            islandContainer.showCustomCapsule();
                            break;
                        case "lyrics":
                            islandContainer.showLyricsCapsule();
                            break;
                        default:
                            islandContainer.swipeTransitionProgress = settleResult.progress;
                        }
                    } else {
                        islandContainer.swipeTransitionProgress = settleResult.progress;
                    }
                    swipeArmed = false;
                    swipeMoved = false;
                }

                onCanceled: {
                    if (preparedOverviewOnPress)
                        root.cancelPreparedOverviewEverywhere();
                    swipeArmed = false;
                    swipeMoved = false;
                    sideSwipeInteractive = false;
                    suppressNextClick = false;
                    preparedOverviewOnPress = false;
                    swipeSuppressReset.stop();
                    mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                    islandContainer.swipeTransitionProgress = islandContainer.swipeRestProgressForState();
                }

                onClicked: (mouse) => {
                    islandContainer.hoverExpandedActive = false;
                    hoverExpandDelayTimer.stop();
                    hoverCollapseDelayTimer.stop();

                    if (suppressNextClick) {
                        swipeSuppressReset.stop();
                        suppressNextClick = false;
                        preparedOverviewOnPress = false;
                        return;
                    }

                    if (mouse.button === Qt.LeftButton && islandContainer.islandState === "normal") {
                        islandContainer.showCalendar(); return;
                    }
                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)) {
                        if (islandContainer.toggleNotificationExpansionIfNeeded()) {
                            if (preparedOverviewOnPress)
                                root.cancelPreparedOverviewEverywhere();
                            preparedOverviewOnPress = false;
                            return;
                        }

                        preparedOverviewOnPress = false;
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandPrimaryAction);
                        return;
                    }

                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandSecondaryButton)) {
                        preparedOverviewOnPress = false;
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandSecondaryAction);
                        return;
                    }

                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandMiddleButton)) {
                        preparedOverviewOnPress = false;
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandMiddleAction);
                        return;
                    }
                }
            }

            MultiPointTouchArea {
                id: twoFingerTouchArea
                anchors.fill: parent
                z: 0
                enabled: !root.overviewVisible
                mouseEnabled: false
                minimumTouchPoints: 2
                maximumTouchPoints: 2

                property real swipeStartX: 0
                property real swipeStartProgress: 0
                property bool swipeMoved: false

                onPressed: (touchPoints) => {
                    const centerPoint = islandContainer.mapFromItem(twoFingerTouchArea, 
                        (touchPoints[0].x + touchPoints[1].x) / 2,
                        (touchPoints[0].y + touchPoints[1].y) / 2);
                    swipeStartX = centerPoint.x;
                    swipeStartProgress = islandContainer.swipeTransitionProgress;
                    swipeMoved = false;
                    islandContainer.cancelSideSwipeSettle();
                }

                onUpdated: (touchPoints) => {
                    const centerPoint = islandContainer.mapFromItem(twoFingerTouchArea, 
                        (touchPoints[0].x + touchPoints[1].x) / 2,
                        (touchPoints[0].y + touchPoints[1].y) / 2);
                    
                    const deltaX = centerPoint.x - swipeStartX;
                    const nextProgress = islandContainer.advanceSideSwipeProgress(
                        swipeStartProgress,
                        deltaX
                    );

                    if (Math.abs(nextProgress - swipeStartProgress) > 0.03) {
                        swipeMoved = true;
                    }

                    islandContainer.swipeTransitionProgress = nextProgress;
                    mainCapsule.displayedWidth = mainCapsule.sideSwipePreviewWidth;
                }

                onReleased: {
                    if (swipeMoved) {
                        const settleResult = islandContainer.resolveSideSwipeSettle(
                            swipeStartProgress,
                            islandContainer.swipeTransitionProgress
                        );

                        islandContainer.beginSideSwipeSettle(settleResult.width);

                        switch (settleResult.action) {
                        case "time":
                            islandContainer.showTimeCapsule();
                            break;
                        case "custom":
                            islandContainer.showCustomCapsule();
                            break;
                        case "lyrics":
                            islandContainer.showLyricsCapsule();
                            break;
                        default:
                            islandContainer.swipeTransitionProgress = settleResult.progress;
                        }
                    } else {
                        islandContainer.swipeTransitionProgress = islandContainer.sideSwipeRestProgressForProgress(swipeStartProgress);
                    }
                    swipeMoved = false;
                }
            }



            IslandContentTransition {
                id: contentTransition
                anchors.fill: parent
                presentation: islandContainer.islandState + "|" + root.overviewContentVisible + "|"
                    + (root.activityLayerOpen ? (activities.detailed ? "detail:" + activities.selected : handoff.main?.id + ":" + handoff.main?.kind) : "")
                    + "|" + islandContainer.notificationExpanded
                edgePanel: root.centerOpen ? islandContainer.islandState : ""
                edgeExit: islandContainer.centerExitProgress
                animate: root.autoHideProgress > 0.98 && !capsuleMouseArea.sideSwipeInteractive
                    && !islandContainer.sideSwipeSettling

                Loader {
                    id: customSwipeLoader
                    anchors.fill: parent
                    active: islandContainer.customSwipeVisible
                    asynchronous: false
                    visible: active && !root.activityLayerOpen

                    onLoaded: islandContainer.syncCustomCapsuleWidth()

                    sourceComponent: Component {
                        SwipeCustomInfoLayer {
                            items: islandContainer.customLeftItems
                            cavaLevels: islandContainer.cavaLevels
                            timeText: timeObj.currentTime
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.heroFontFamily
                            timeFontFamily: root.heroFontFamily
                            textPixelSize: root.bodyFontSize
                            iconPixelSize: root.iconFontSize
                            minimumWidth: 220
                            maximumWidth: Math.max(220, root.width - 48)
                            transitionProgress: islandContainer.swipeTransitionProgress
                            recordingActive: islandContainer.screenRecordingActive
                            showSecondaryText: islandContainer.workspaceOriginSide !== "left"
                                && islandContainer.splitOriginSide !== "left"
                            showCondition: true
                            onPreferredWidthChanged: islandContainer.syncCustomCapsuleWidth()
                        }
                    }
                }

                Loader {
                    id: lyricsSwipeLoader
                    anchors.fill: parent
                    active: islandContainer.lyricsSwipeVisible
                    asynchronous: false
                    visible: active && !root.activityLayerOpen

                    onLoaded: islandContainer.syncLyricsCapsuleWidth()

                    sourceComponent: Component {
                        SwipeLyricsLayer {
                            lyricText: islandContainer.lyricsDisplayText
                            currentArtUrl: islandContainer.currentArtUrl
                            cavaLevels: islandContainer.cavaLevels
                            timeText: timeObj.currentTime
                            textFontFamily: root.textFontFamily
                            timeFontFamily: root.timeFontFamily
                            textPixelSize: root.bodyFontSize
                            minimumWidth: 220
                            maximumWidth: Math.max(220, root.width - 48)
                            transitionProgress: islandContainer.rightSwipeProgress
                            recordingActive: islandContainer.screenRecordingActive
                            showSecondaryText: islandContainer.workspaceOriginSide !== "right"
                                && islandContainer.splitOriginSide !== "right"
                            showCondition: true
                            onPreferredWidthChanged: islandContainer.syncLyricsCapsuleWidth()
                        }
                    }
                }

                Loader {
                    id: splitIconLoader
                    anchors.fill: parent
                    active: !root.overviewVisible && islandContainer.splitShowsIconOnly
                    asynchronous: false
                    visible: active

                    sourceComponent: Component {
                        SplitIconLayer {
                            iconText: islandContainer.splitIcon
                            iconFontFamily: root.iconFontFamily
                            transitionProgress: islandContainer.swipeTransitionProgress
                            slideDirection: islandContainer.splitOriginSide
                            showCondition: true
                        }
                    }
                }

                Loader {
                    id: osdLayerLoader
                    anchors.fill: parent
                    active: !root.overviewVisible && islandContainer.splitUsesExtendedLayout
                    asynchronous: false
                    visible: active

                    sourceComponent: Component {
                        OsdLayer {
                            iconText: islandContainer.splitIcon
                            levelKind: islandContainer.levelOsdKind
                            progress: islandContainer.osdProgress
                            customText: islandContainer.osdCustomText
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            heroFontFamily: root.heroFontFamily
                            transitionProgress: islandContainer.swipeTransitionProgress
                            slideDirection: islandContainer.splitOriginSide
                            showCondition: true
                        }
                    }
                }

                Loader {
                    id: workspaceLayerLoader
                    anchors.fill: parent
                    active: !root.overviewVisible && islandContainer.islandState === "long_capsule"
                        && (islandContainer.workspaceOriginSide !== "none"
                            || Math.abs(islandContainer.swipeTransitionProgress) < 0.001)
                    asynchronous: false
                    visible: active

                    sourceComponent: Component {
                        WorkspaceLayer {
                            workspaceId: islandContainer.currentWs
                            displayText: "Workspace " + islandContainer.currentWs
                            outputName: root.compositorIsNiri ? root.screenOutputName : ""
                            textFontFamily: root.textFontFamily
                            textPixelSize: root.bodyFontSize
                            animateVisibility: islandContainer.workspaceOriginSide !== "none"
                            transitionProgress: islandContainer.swipeTransitionProgress
                            showCondition: true
                            slideDirection: islandContainer.workspaceOriginSide
                        }
                    }
                }


                AppIconQueue {
                    id: appIconQueue
                    anchors.fill: parent
                    active: islandContainer.islandState === "app_queue"
                    revealed: root.autoHideProgress >= 0.98
                    onDismissRequested: islandContainer.smartRestoreState()
                }

                Loader {
                    id: expandedPlayerLoader
                    anchors.fill: parent
                    active: islandContainer.expandedLayerVisible
                    asynchronous: false
                    visible: active
                    onLoaded: {
                        if (islandContainer.openTimerPageWhenExpanded
                                && item && item.openTimerPage) {
                            item.openTimerPage();
                            islandContainer.openTimerPageWhenExpanded = false;
                        }
                        root.focusExpandedPlayer();
                    }

                    sourceComponent: Component {
                        ExpandedPlayerLayer {
                            currentArtUrl: islandContainer.currentArtUrl
                            currentTrack: islandContainer.currentTrack
                            currentArtist: islandContainer.currentArtist
                            timePlayed: islandContainer.timePlayed
                            timeTotal: islandContainer.timeTotal
                            trackProgress: islandContainer.trackProgress
                            activePlayer: islandContainer.activePlayer
                            spotifyFavorites: mediaController.spotifyFavorites
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            timerSelectedHours: islandContainer.timerSelectedHours
                            timerSelectedMinutes: islandContainer.timerSelectedMinutes
                            timerTotalSeconds: islandContainer.timerTotalSeconds
                            timerRemainingSeconds: islandContainer.timerRemainingSeconds
                            timerRunning: islandContainer.timerRunning
                            timerActive: islandContainer.timerActive
                            showCondition: islandContainer.expandedLayerVisible
                            onControlPressed: {
                                if (root.sourcePlayerExpanded) {
                                    activities.activatedSourceId = "";
                                    islandContainer.requestExpandedPlayerKeyboardFocus();
                                }
                                islandContainer.suppressCapsuleClick();
                            }
                            onBackgroundClicked: {
                                if (islandContainer.activePlayer) activities.activatePlayerSource();
                                else islandContainer.smartRestoreState();
                            }
                            onCloseRequested: islandContainer.smartRestoreState()
                            onKeyboardFocusRequested: islandContainer.requestExpandedPlayerKeyboardFocus()
                            onKeyboardFocusReleased: islandContainer.releaseExpandedPlayerKeyboardFocus()
                            onPreviousRequested: mediaController.previous()
                            onTimerToggleRequested: function(hours, minutes) {
                                islandContainer.toggleTimer(hours, minutes);
                            }
                            onTimerResetRequested: islandContainer.resetTimer()
                            onTimerDurationRequested: function(hours, minutes) {
                                if (!islandContainer.timerActive)
                                    islandContainer.syncTimerDuration(hours, minutes);
                            }
                        }
                    }
                }

                Loader {
                    id: bluetoothExpandedLoader
                    anchors.fill: parent
                    active: islandContainer.bluetoothExpandedLayerVisible
                    asynchronous: false
                    visible: active

                    sourceComponent: Component {
                        BluetoothExpandedLayer {
                            device: islandContainer.bluetoothExpandedDevice
                            volumeLevel: islandContainer.currentVolume
                            iconText: ""
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            showCondition: islandContainer.bluetoothExpandedLayerVisible
                        }
                    }
                }

                Loader {
                    id: notificationLoader
                    anchors.fill: parent
                    active: islandContainer.notificationLayerVisible
                    asynchronous: false
                    visible: active

                    sourceComponent: Component {
                        NotificationLayer {
                            appName: islandContainer.notificationAppName
                            summary: islandContainer.notificationSummary
                            body: islandContainer.notificationBody
                            expanded: islandContainer.notificationExpanded
                            toggleButton: userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)
                            iconText: root.notificationStatusIcon
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            heroFontFamily: root.heroFontFamily
                            showCondition: true
                            onExpansionToggleRequested: {
                                islandContainer.suppressCapsuleClick(true);
                                islandContainer.toggleNotificationExpansionIfNeeded();
                            }
                        }
                    }
                }

                ActivityHandoff {
                    id: handoff
                    foreground: activities.current
                    secondary: activities.chip
                    animate: root.activityPresentationAllowed && !activities.detailed && !clickMerge.source && !clickMerge.returnSource
                    onMerging: (row, finished) => {
                        if (row && ["done", "notification"].includes(row.kind) && root.activityHub?.send)
                            root.activityHub.send({op:"presentation", id:row.id, updated:row.updated, finished})
                    }
                }
                ActivityCapsule {
                    presented: handoff.main
                    opacity: handoff.mainOpacity
                    enabled: !handoff.moving
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
                    id: controlCenterLoader
                    anchors.fill: parent
                    active: islandContainer.controlCenterLayerVisible || root.anyConnectivityDetailMounted
                    asynchronous: false
                    visible: active

                    sourceComponent: Component {
                        ControlCenterLayer {
                            activityHub: root.activityHub
                            onDismissRequested: islandContainer.smartRestoreState()
                            onTimerRequested: islandContainer.showExpandedTimerPage()
                            onLockRequested: {
                                islandContainer.smartRestoreState();
                                if (root.shellRootController)
                                    root.shellRootController.lockScreen();
                            }
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            heroFontFamily: root.heroFontFamily
                            sliderIntroDelay: 0
                            currentTime: timeObj.currentTime
                            currentDateLabel: timeObj.currentDateLabel
                            batteryCapacity: islandContainer.batteryCapacity
                            isCharging: islandContainer.isCharging
                            volumeLevel: islandContainer.currentVolume
                            volumeMuted: islandContainer.isMuted
                            brightnessLevel: islandContainer.currentBrightness
                            currentWorkspace: islandContainer.currentWs
                            currentTrack: islandContainer.currentTrack
                            currentArtist: islandContainer.currentArtist
                            nightLightEnabled: root.shellRootController && root.shellRootController.nightLightEnabled !== undefined
                                ? root.shellRootController.nightLightEnabled
                                : false
                            showCondition: islandContainer.controlCenterLayerVisible
                            onFocusModeChanged: function(enabled) {
                                if (root.shellRootController && root.shellRootController.focusEnabled !== undefined)
                                    root.shellRootController.focusEnabled = enabled;
                            }
                            onNightLightModeChanged: function(enabled) {
                                if (root.shellRootController && root.shellRootController.nightLightEnabled !== undefined)
                                    root.shellRootController.nightLightEnabled = enabled;
                            }
                            onRequestNotification: function(appName, summary, body) {
                                islandContainer.showNotificationCapsule(appName, summary, body);
                            }
                            onConnectivityPanelRequested: function(kind, open) {
                                root.setConnectivityDetailVisible(kind, open);
                            }
                            weatherService: root.weatherService
                            onWeatherRequested: islandContainer.showWeather()
                            onCalendarRequested: islandContainer.showCalendar()
                        }
                    }
                }

                Loader {
                    id: notificationCenterLoader
                    anchors.fill: parent
                    active: islandContainer.notificationCenterLayerVisible
                    asynchronous: false
                    visible: active
                    onLoaded: islandContainer.forceActiveFocus()

                    sourceComponent: Component {
                        ActivityHistory { hub: root.activityHub }
                    }
                }

                Loader {
                    id: wallpaperPickerLoader
                    anchors.fill: parent
                    active: islandContainer.wallpaperPickerLayerVisible
                    asynchronous: false
                    visible: islandContainer.wallpaperPickerLayerVisible
                    onLoaded: root.focusWallpaperPicker()

                    sourceComponent: Component {
                        WallpaperPickerLayer {
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            activeWallpaper: root.wallpaperPickerActiveWallpaper
                            showCondition: islandContainer.wallpaperPickerLayerVisible
                            onWallpaperApplied: filePath => root.wallpaperPickerActiveWallpaper = filePath
                            onWallpaperApplySucceeded: filePath => root.handleWallpaperApplySucceeded(filePath)
                            onCloseRequested: islandContainer.smartRestoreState()
                        }
                    }
                }

                Loader {
                    id: applicationLauncherLoader
                    anchors.fill: parent
                    active: islandContainer.applicationLauncherLayerVisible
                    asynchronous: false
                    visible: islandContainer.applicationLauncherLayerVisible
                    onLoaded: root.focusApplicationLauncher()

                    sourceComponent: Component {
                        ApplicationLauncherLayer {
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            searchMode: root.launcherSearchMode
                            searchEntries: root.launcherSearchEntries
                            showCondition: islandContainer.applicationLauncherLayerVisible
                            onCloseRequested: islandContainer.smartRestoreState()
                        }
                    }
                }

                Loader {
                    id: fileShelfLoader
                    anchors.fill: parent
                    active: islandContainer.fileShelfLayerVisible
                    asynchronous: false
                    visible: islandContainer.fileShelfLayerVisible
                    onLoaded: {
                        if (islandContainer.fileShelfOpenedManually)
                            root.focusFileShelf();
                    }

                    sourceComponent: Component {
                        FileShelfLayer {
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            showCondition: islandContainer.fileShelfLayerVisible
                            dropPreviewOnly: !islandContainer.fileShelfOpenedManually
                            onCloseRequested: islandContainer.smartRestoreState()
                        }
                    }
                }

                Loader {
                    id: clipboardLoader
                    anchors.fill: parent
                    active: islandContainer.clipboardLayerVisible
                    asynchronous: false
                    visible: islandContainer.clipboardLayerVisible
                    onLoaded: root.focusClipboard()

                    sourceComponent: Component {
                        ClipboardLayer {
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            showCondition: islandContainer.clipboardLayerVisible
                            onCloseRequested: islandContainer.smartRestoreState()
                        }
                    }
                }

                Loader {
                    id: weatherLoader
                    anchors.fill: parent
                    active: islandContainer.weatherLayerVisible
                    asynchronous: false
                    visible: islandContainer.weatherLayerVisible
                    onLoaded: islandContainer.forceActiveFocus()

                    sourceComponent: Component {
                        WeatherLayer {
                            weatherService: root.weatherService
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            heroFontFamily: root.heroFontFamily
                            showCondition: islandContainer.weatherLayerVisible
                            onCloseRequested: islandContainer.smartRestoreState()
                        }
                    }
                }

                Loader {
                    id: calendarLoader
                    anchors.fill: parent
                    active: islandContainer.calendarLayerVisible
                    asynchronous: false
                    visible: islandContainer.calendarLayerVisible
                    onLoaded: islandContainer.forceActiveFocus()

                    sourceComponent: Component {
                        CalendarLayer {
                            iconFontFamily: root.iconFontFamily
                            textFontFamily: root.textFontFamily
                            heroFontFamily: root.heroFontFamily
                            showCondition: islandContainer.calendarLayerVisible
                            onCloseRequested: islandContainer.smartRestoreState()
                        }
                    }
                }

                DropArea {
                    id: islandFileDropArea
                    z: 10000
                    anchors.fill: parent
                    enabled: islandContainer.fileShelfLayerVisible
                        || islandContainer.fileShelfCanAutoOpen

                    onEntered: drag => {
                        if (!root.dragCarriesFiles(drag)) {
                            drag.accepted = false;
                            return;
                        }

                        drag.accept(Qt.CopyAction);
                        if (!islandContainer.fileShelfLayerVisible)
                            islandContainer.showFileShelf(false);
                        root.showAutoHiddenIsland("state");
                    }

                    onExited: islandContainer.closeAutoOpenedFileShelf()

                    onDropped: drop => {
                        if (!root.dragCarriesFiles(drop)) {
                            drop.accepted = false;
                            return;
                        }

                        root.addFilesFromDrop(drop);
                        drop.accept(Qt.CopyAction);
                        islandContainer.closeAutoOpenedFileShelf();
                    }
                }

                Rectangle {
                    z: 9999
                    anchors.fill: parent
                    radius: mainCapsule.radius
                    color: StyleTokens.clearBlack
                    border.width: islandFileDropArea.containsDrag ? 2 : 0
                    border.color: StyleTokens.accent
                    visible: islandFileDropArea.containsDrag
                }

                Loader {
                    id: overviewLoader

                    anchors.fill: parent
                    active: root.overviewLoaderActive
                    asynchronous: false
                    visible: root.overviewContentVisible

                    onStatusChanged: {
                        if (status === Loader.Ready && root.overviewPreparing) {
                            root.beginOverviewOpening();
                            root.focusOverview();
                        }
                    }

                    sourceComponent: Component {
                        WorkspaceOverviewScene {
                            screen: root.screen
                            showCondition: root.overviewVisible
                            previewsEnabled: root.overviewContentVisible
                            textFontFamily: root.textFontFamily
                            heroFontFamily: root.heroFontFamily
                            wallpaperPath: root.overviewWallpaperSource
                            windowCornerRadius: root.overviewWindowCornerRadius
                            onCloseRequested: root.closeOverviewEverywhere()
                        }
                    }
                }
            }

        }

        QtObject {
            id: clickMerge
            property Item source: null
            property Item returnSource: null
            property string returnActivityId: ""
            property string detailState: ""
            property bool returning: false
            readonly property point destination: returning && source?.parent
                ? source.parent.mapToItem(islandContainer, source.x + source.width / 2, source.y + source.height / 2)
                : origin
            readonly property string currentDetail: islandContainer.islandState + "|" + activities.selected + "|" + activities.listing
            onCurrentDetailChanged: if (returnSource) Qt.callLater(restoreSource)

            function restoreSource() {
                if (!returnSource || currentDetail === detailState) return
                const item = returnSource
                const activityId = returnActivityId
                // The completion bubble is temporary. Restore it only while that event is live.
                if (item === timerBubble && islandContainer.timerBubbleWanted) {
                    timerBubbleHideAnimation.stop()
                    timerBubbleShowAnimation.stop()
                    timerBubble.reveal = 1
                    timerBubble.mounted = true
                }
                handoff.reconcile()
                returnSource = null
                if (root.overviewVisible || (!root.activityPresentationAllowed && !activityChips.expandedMusic)
                        || activities.detailed || !item.visible
                        || (item === activityChip && activityChips.smallItem?.id !== activityId))
                    return
                origin = item.mapToItem(islandContainer, item.width / 2, item.height / 2)
                returning = true
                phase = 0
                source = item
                motion.start()
            }
            property point origin
            property real phase: 1
            property var action: null
            function open(item, callback) {
                if (source || !item.visible) return
                origin = item.mapToItem(islandContainer, item.width / 2, item.height / 2)
                returning = false
                phase = 1
                returnActivityId = item === activityChip ? activityChips.smallItem?.id || "" : ""
                action = callback
                source = item
                motion.start()
            }
            function cancel() {
                motion.stop()
                source = null
                returning = false
                action = null
            }
            readonly property NumberAnimation motion: NumberAnimation {
                target: clickMerge
                property: "phase"
                from: clickMerge.returning ? 0 : 1
                to: clickMerge.returning ? 1 : 0
                duration: clickMerge.returning ? 420 : 300
                easing.type: Easing.Linear
                onFinished: {
                    const callback = clickMerge.action
                    const item = clickMerge.source
                    const previous = clickMerge.currentDetail
                    if (callback && item?.visible && !root.overviewVisible) {
                        callback()
                        if (clickMerge.currentDetail !== previous) {
                            clickMerge.detailState = clickMerge.currentDetail
                            clickMerge.returnSource = item
                        }
                    }
                    clickMerge.cancel()
                }
            }
        }

        LiquidCapsule {
            id: liquid
            main: mainCapsule
            readonly property bool clicked: !!clickMerge.source
            readonly property bool app: !clicked && appIconQueue.active && appIconQueue.movingApp !== ""
            readonly property bool chip: handoff.moving && activityChips.progress > 0 && activityChips.progress < 1
            // Phase grows toward detachment in both directions. The row and
            // body settle before the satellite reaches the end of its travel.
            readonly property real phase: clicked ? clickMerge.phase : app ? appIconQueue.separation : activityChips.progress
            readonly property bool releasing: clicked ? clickMerge.returning : app ? !appIconQueue.opening : (handoff.moving ? handoff.direction === "split" : activityChips.wanted)
            readonly property real separation: appIconQueue.smoothPhase(phase, 0, releasing ? 0.62 : 0.84)
            readonly property real rebound: releasing
                ? Math.sin(Math.PI * appIconQueue.smoothPhase(phase, 0.45, 0.89)) : 0
            readonly property real emerge: app ? 1 - appIconQueue.smoothPhase(phase, 0.86, 1) : 1
            readonly property real contact: Math.sin(Math.PI * separation)
            readonly property int side: clicked ? (clickMerge.destination.x < mainCapsule.x + mainCapsule.width / 2 ? -1 : 1) : app ? (userConfig.islandPositionX <= 50 ? 1 : -1)
                : (activityChips.restX + activityChip.width / 2 >= mainCapsule.x + mainCapsule.width / 2 ? 1 : -1)
            readonly property real edge: mainCapsule.x + (side > 0 ? mainCapsule.width : 0)
            readonly property real diameter: root.compactCapsuleHeight
            readonly property real dock: app ? mainCapsule.x + appIconQueue.slotX
                : edge - side * Math.min(mainCapsule.width / 2, diameter / 2)
            readonly property real detached: clicked ? clickMerge.destination.x : app ? edge + side * (diameter / 2 + 10 + root.capsuleFrameWidth)
                : activityChips.restX + activityChip.width / 2
            satelliteX: dock + (detached - dock) * separation + side * rebound * diameter * 0.36
            satelliteY: clicked ? clickMerge.destination.y
                : mainCapsule.y + mainCapsule.height / 2
            satelliteWidth: (clicked ? clickMerge.source.width : app ? diameter : activityChip.width) * (1 + 0.085 * contact - 0.12 * rebound) * emerge
            satelliteHeight: (clicked ? clickMerge.source.height : app ? diameter : activityChip.height) * (1 + 0.085 * contact + 0.10 * rebound) * emerge
            stroke: root.capsuleFrameWidth
            fillTint: root.materialColor
            edgeTint: mainCapsule.outlineColor
            z: mainCapsule.z - 0.1
            visible: (clicked || (app || chip) && mainCapsule.roundedCapsule) && root.autoHideProgress > 0.98
                && GraphicsInfo.api !== GraphicsInfo.Software
            opacity: mainCapsule.opacity
        }
        Rectangle {
            id: appBubble
            x: liquid.satelliteX - width / 2
            y: mainCapsule.y + (mainCapsule.height - height) / 2
            width: liquid.app ? liquid.satelliteWidth : 0
            height: liquid.app ? liquid.satelliteHeight : 0
            radius: Math.min(width, height) / 2
            z: mainCapsule.z - 0.1
            color: liquid.visible ? "transparent" : root.materialColor
            visible: liquid.app
        }
        QueueAppIcon {
            visible: liquid.app
            iconSource: appIconQueue.movingIcon
            width: 20
            height: 20
            x: liquid.satelliteX - width / 2
            y: mainCapsule.y + (mainCapsule.height - height) / 2
            opacity: mainCapsule.opacity * liquid.emerge
            scale: liquid.emerge
            z: mainCapsule.z + 2
            layer.enabled: liquid.contact > 0.01
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 8; blur: liquid.contact * 0.75 }
        }

        Row {
            id: activityChips
            readonly property bool expandedMusic: islandContainer.expandedLayerVisible && activities.playing
            readonly property var others: expandedMusic ? activities.rows.filter(r => r.kind !== "music") : activities.secondary
            readonly property var smallItem: expandedMusic ? others[0] || null : handoff.chip
            spacing: 3 + root.chipFrameWidth * 2
            readonly property bool compactTransient: ["split", "long_capsule", "app_queue"].includes(islandContainer.islandState)
                && !root.overviewVisible
            readonly property bool wanted: (root.activityPresentationAllowed || expandedMusic || compactTransient)
                && !!smallItem && !activities.listing
            property var retained: null
            onSmallItemChanged: if (smallItem) retained = smallItem
            readonly property real progress: handoff.moving ? handoff.separation : reveal
            readonly property real reveal: wanted && handoff.direction !== "merge" ? 1 : 0
            readonly property real gap: 5 + root.capsuleFrameWidth + root.chipFrameWidth
            readonly property real restX: mainCapsule.x + mainCapsule.width + gap + width <= parent.width
                ? mainCapsule.x + mainCapsule.width + gap : Math.max(0, mainCapsule.x - gap - width)
            y: mainCapsule.y + ((mainCapsule.roundedCapsule ? mainCapsule.height : userConfig.islandHeight) - height) / 2
            x: liquid.chip && !liquid.clicked && !liquid.app && mainCapsule.roundedCapsule ? liquid.satelliteX - activityChip.width / 2 : restX
            z: 8; opacity: root.autoHideProgress
            transform: Scale {
                origin.y: activityChips.height / 2
                yScale: mainCapsule.roundedCapsule ? mainCapsule.revealHeightScale : 1
            }
            visible: progress > 0 && opacity > 0.01 && (wanted || mainCapsule.roundedCapsule && !liquid.app)
            enabled: wanted && !handoff.moving && !clickMerge.source
            IslandButton {
                id: activityChip
                transform: Translate { x: clickMerge.source === activityChip ? liquid.satelliteX - clickMerge.destination.x : 0 }
                height: root.compactCapsuleHeight
                width: Math.max(height, implicitWidth)
                surfaceColor: root.materialColor
                opacity: clickMerge.source === activityChip ? liquid.separation : 1
                outsideFrame: true
                capsuleFrameWidth: userConfig.islandFrameWidth
                outlineColor: mainCapsule.outlineColor
                pixelRatio: root.devicePixelRatio
                visible: !!(activityChips.smallItem || activityChips.retained)
                surfaceOpacity: liquid.visible && !liquid.app && (!liquid.clicked || clickMerge.source === activityChip) ? 0 : 1
                labelOpacity: activityChips.progress
                labelBlur: (liquid.chip && !liquid.app || clickMerge.source === activityChip) ? liquid.contact : 0
                text: activities.glyph((activityChips.smallItem || activityChips.retained)?.kind || "")
                description: activityChips.smallItem ? activityChips.smallItem.title : ""
                onClicked: {
                    const id = activityChips.smallItem?.id
                    clickMerge.open(activityChip, () => {
                        const row = activities.rows.find(item => item.id === id)
                        if (!row) return
                        if (activityChips.expandedMusic) islandContainer.smartRestoreState()
                        activities.expand(row)
                    })
                }
            }
            IslandButton {
                id: moreActivityChip
                transform: Translate { x: clickMerge.source === moreActivityChip ? liquid.satelliteX - clickMerge.destination.x : 0 }
                height: root.compactCapsuleHeight
                width: Math.max(height, implicitWidth)
                surfaceColor: root.materialColor
                opacity: clickMerge.source === moreActivityChip ? liquid.separation : 1
                outsideFrame: true
                capsuleFrameWidth: userConfig.islandFrameWidth
                outlineColor: mainCapsule.outlineColor
                pixelRatio: root.devicePixelRatio
                surfaceOpacity: liquid.visible && clickMerge.source === moreActivityChip ? 0 : 1
                visible: activityChips.others.length > 1
                text: "+" + Math.max(0, activityChips.others.length - 1); description: "All activities"
                onClicked: {
                    clickMerge.open(moreActivityChip, () => {
                        if (activityChips.expandedMusic) islandContainer.smartRestoreState()
                        activities.closeDetails()
                        activities.listing = true
                    })
                }
            }
        }
        Item {
            id: fileShelfBubble
            transform: Translate { x: clickMerge.source === fileShelfBubble ? liquid.satelliteX - clickMerge.destination.x : 0 }

            readonly property real bubbleSize: root.compactCapsuleHeight

            width: bubbleSize
            height: bubbleSize
            x: mainCapsule.x - width - Math.max(8, root.capsuleFrameWidth + 4)
            y: mainCapsule.y + mainCapsule.height / 2 - height / 2
            z: 6
            visible: islandContainer.fileShelfBubbleWanted
            opacity: root.autoHideProgress * (clickMerge.source === fileShelfBubble ? liquid.separation : 1)
            scale: mainCapsule.revealHeightScale
            transformOrigin: Item.Center

            Behavior on opacity {
                NumberAnimation { duration: StyleTokens.durationFast }
            }

            IslandSurface {
                anchors.fill: parent
                tint: StyleTokens.panel
                materialOpacity: liquid.visible && clickMerge.source === fileShelfBubble ? 0 : root.materialOpacity
                frameColor: Qt.alpha(StyleTokens.surfaceBorder, StyleTokens.surfaceBorder.a * root.compactKeyline)
                outsideFrame: true
                frameWidth: liquid.visible && clickMerge.source === fileShelfBubble ? 0 : userConfig.islandFrameWidth
                pixelRatio: root.devicePixelRatio
                radius: width / 2
                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -1
                    text: "\uf08d"
                    color: StyleTokens.textPrimary
                    font.family: root.iconFontFamily
                    font.pixelSize: 13
                    rotation: -18
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 1
                    anchors.bottomMargin: 1
                    width: Math.max(17, countText.implicitWidth + 8)
                    height: 17
                    radius: height / 2
                    color: StyleTokens.accent
                    border.width: 2
                    border.color: StyleTokens.black

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: FileShelf.count > 99 ? "99+" : String(FileShelf.count)
                        color: StyleTokens.white
                        font.family: root.textFontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: fileShelfBubble.visible && root.autoHideProgress > 0.5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    clickMerge.open(fileShelfBubble, () => {
                        islandContainer.showFileShelf(true)
                        root.showAutoHiddenIsland("state")
                    })
                }
            }
        }

        Item {
            id: timerBubble
            transform: Translate { x: clickMerge.source === timerBubble ? liquid.satelliteX - clickMerge.destination.x : 0 }

            property bool mounted: islandContainer.timerBubbleWanted
            property real reveal: islandContainer.timerBubbleWanted ? 1 : 0
            readonly property real bubbleSize: root.compactCapsuleHeight
            readonly property real hiddenX: mainCapsule.x + mainCapsule.width - width * 0.62
            readonly property real shownX: mainCapsule.x + mainCapsule.width + Math.max(8, root.capsuleFrameWidth + 4)
            readonly property real centerY: mainCapsule.y + mainCapsule.height / 2 - height / 2

            width: bubbleSize
            height: bubbleSize
            x: hiddenX + (shownX - hiddenX) * reveal
            y: centerY + (1 - reveal) * 10
            z: 6
            visible: mounted
            opacity: reveal * root.autoHideProgress * (clickMerge.source === timerBubble ? liquid.separation : 1)
            scale: (0.55 + reveal * 0.45) * mainCapsule.revealHeightScale * (1 + islandContainer.timerCompletionPulse * 0.12)
            transformOrigin: Item.Center

            Connections {
                target: islandContainer

                function onTimerBubbleWantedChanged() {
                    timerBubbleShowAnimation.stop();
                    timerBubbleHideAnimation.stop();

                    if (islandContainer.timerBubbleWanted) {
                        timerBubble.mounted = true;
                        timerBubbleShowAnimation.restart();
                    } else {
                        timerBubbleHideAnimation.restart();
                    }
                }

                function onTimerProgressChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerRemainingSecondsChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerTotalSecondsChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerCompletionAnimatingChanged() {
                    timerBubbleRing.requestPaint();
                }

                function onTimerCompletionFlashChanged() {
                    timerBubbleRing.requestPaint();
                }
            }

            NumberAnimation {
                id: timerBubbleShowAnimation

                target: timerBubble
                property: "reveal"
                from: timerBubble.reveal
                to: 1
                duration: 360
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: timerBubbleHideAnimation

                target: timerBubble
                property: "reveal"
                from: timerBubble.reveal
                to: 0
                duration: 280
                easing.type: Easing.InCubic
                onStopped: {
                    if (!islandContainer.timerBubbleWanted && timerBubble.reveal <= 0.001)
                        timerBubble.mounted = false;
                }
            }

            SequentialAnimation {
                id: timerBubbleCompletionAnimation

                running: islandContainer.timerCompletionAnimating

                onStarted: {
                    timerBubbleShowAnimation.stop();
                    timerBubbleHideAnimation.stop();
                    timerBubble.mounted = true;
                    timerBubble.reveal = 1;
                }

                onStopped: {
                    if (islandContainer.timerCompletionAnimating)
                        islandContainer.timerCompletionAnimating = false;
                    islandContainer.timerCompletionPulse = 0;
                    islandContainer.timerCompletionFlash = 0;
                    timerBubbleRing.requestPaint();
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionPulse"
                        from: 0
                        to: 1
                        duration: 140
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionFlash"
                        from: 0
                        to: 1
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionPulse"
                        from: 1
                        to: 0
                        duration: 380
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: islandContainer
                        property: "timerCompletionFlash"
                        from: 1
                        to: 0
                        duration: 380
                        easing.type: Easing.InOutQuad
                    }
                }

                PauseAnimation {
                    duration: 380
                }
            }

            IslandSurface {
                anchors.fill: parent
                tint: StyleTokens.panel
                materialOpacity: liquid.visible && clickMerge.source === timerBubble ? 0 : root.materialOpacity
                frameColor: Qt.alpha(StyleTokens.surfaceBorder, StyleTokens.surfaceBorder.a * root.compactKeyline)
                outsideFrame: true
                frameWidth: liquid.visible && clickMerge.source === timerBubble ? 0 : userConfig.islandFrameWidth
                pixelRatio: root.devicePixelRatio
                radius: width / 2
            }

            Canvas {
                id: timerBubbleRing

                anchors.fill: parent
                anchors.margins: 1

                Component.onCompleted: requestPaint()
                onVisibleChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    const centerX = width / 2;
                    const centerY = height / 2;
                    const completionActive = islandContainer.timerCompletionAnimating;
                    const flash = Math.max(0, Math.min(1, islandContainer.timerCompletionFlash));
                    const lineWidth = completionActive ? 3 + flash : 3;
                    const radius = Math.min(width, height) / 2 - lineWidth / 2;
                    const progress = Math.max(0, Math.min(1, islandContainer.timerProgress));
                    const startAngle = -Math.PI / 2;
                    const endAngle = startAngle - Math.PI * 2 * progress;

                    ctx.clearRect(0, 0, width, height);
                    ctx.lineCap = "round";
                    ctx.lineWidth = lineWidth;

                    ctx.beginPath();
                    ctx.strokeStyle = "#303036";
                    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                    ctx.stroke();

                    if (completionActive) {
                        if (flash > 0) {
                            ctx.beginPath();
                            ctx.lineWidth = lineWidth + 1.5;
                            ctx.strokeStyle = "rgba(255, 204, 0, " + (0.18 * flash) + ")";
                            ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                            ctx.stroke();
                        }

                        ctx.beginPath();
                        ctx.lineWidth = lineWidth;
                        ctx.strokeStyle = "rgba(255, 204, 0, " + (0.72 + 0.28 * flash) + ")";
                        ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                        ctx.stroke();
                    } else if (progress > 0) {
                        ctx.beginPath();
                        ctx.strokeStyle = "#ffcc00";
                        ctx.arc(centerX, centerY, radius, startAngle, endAngle, true);
                        ctx.stroke();
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -1
                text: "󰔛"
                color: "white"
                font.pixelSize: root.iconFontSize - 1
                font.family: root.iconFontFamily
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                enabled: timerBubble.mounted && root.autoHideProgress > 0.5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (root.autoHideEnabled) {
                        root.autoHidePointerInside = true;
                        root.showAutoHiddenIsland();
                    }
                }
                onExited: {
                    if (root.autoHideEnabled) {
                        root.autoHidePointerInside = false;
                        root.scheduleAutoHide();
                    }
                }
                onClicked: clickMerge.open(timerBubble, () => {
                    islandContainer.showExpandedTimerPage()
                    timerBubbleHideAnimation.stop()
                    timerBubble.reveal = 0
                    timerBubble.mounted = false
                })
            }
        }

        ConnectivityDetailShell {
            id: wifiConnectivityDetailShell
            materialOpacity: root.materialOpacity

            open: root.wifiConnectivityDetailOpen
            mounted: root.wifiConnectivityDetailMounted
            rightSide: false
            panelKind: "wifi"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            availableWidth: root.width
            detailWidth: root.connectivityDetailWidth
            detailHeight: root.connectivityDetailHeight
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        ConnectivityDetailShell {
            id: bluetoothConnectivityDetailShell
            materialOpacity: root.materialOpacity

            open: root.bluetoothConnectivityDetailOpen
            mounted: root.bluetoothConnectivityDetailMounted
            rightSide: true
            panelKind: "bluetooth"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            availableWidth: root.width
            detailWidth: root.connectivityDetailWidth
            detailHeight: root.connectivityDetailHeight
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        ConnectivityDetailShell {
            id: powerConnectivityDetailShell
            materialOpacity: root.materialOpacity

            open: root.powerConnectivityDetailOpen
            mounted: root.powerConnectivityDetailMounted
            rightSide: true
            panelKind: "power"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            availableWidth: root.width
            detailWidth: 260
            detailHeight: 88
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        CalendarNoteShell {
            id: calendarNoteShell
            materialOpacity: root.materialOpacity

            open: islandContainer.calendarLayerVisible
                && calendarLoader.item !== null
                && calendarLoader.item.noteOpen
            provider: calendarLoader.item
            mainCapsule: mainCapsule
            availableWidth: root.width
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }
    }

    MouseArea {
        id: autoHideRevealArea

        x: root.autoHideRevealX
        y: 0
        z: 20
        width: root.autoHideRevealWidth
        height: root.autoHideRevealHeight
        enabled: height > 0
        hoverEnabled: enabled
        acceptedButtons: Qt.NoButton

        onEntered: {
            root.autoHidePointerInside = true;
            root.showAutoHiddenIsland("edge");
        }

        onExited: {
            root.autoHidePointerInside = false;
            root.scheduleAutoHide();
        }
    }

    IslandRootGestureArea {
        x: Math.min(root.topGestureInputX, mainCapsule.x)
        width: Math.max(root.topGestureInputX + root.topGestureInputWidth, mainCapsule.x + mainCapsule.width) - x
        height: root.autoHideTargetVisible ? mainCapsule.y + mainCapsule.height : root.topGestureInputHeight
        enabled: root.topGestureInputActive
        islandController: islandContainer
        capsule: mainCapsule
    }
}
