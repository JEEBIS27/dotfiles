import QtQuick

// Keep the old foreground and the traveling chip alive across a change in rank.
QtObject {
    id: handoff
    required property var foreground
    required property var secondary
    required property bool animate
    property var main: null
    property var chip: null
    property var nextMain: null
    property var nextChip: null
    property string direction: ""
    property real phase: 0
    readonly property bool moving: direction !== ""
    readonly property real separation: direction === "split" ? phase : 1 - phase
    readonly property real mainOpacity: !moving ? 1 : phase < contact
        ? 1 - phase / contact : Math.min(1, (phase - contact) / 0.4)
    readonly property real contact: direction === "split" ? 0.30 : 0.37
    signal merging(var row, bool finished)

    function reconcile() {
        if (!animate) {
            motion.stop()
            direction = ""
        } else if (moving) {
            return
        }
        if (animate && chip && foreground && chip.id === foreground.id && chip.id !== main?.id) {
            phase = 0
            direction = "merge"
            merging(foreground, false)
        } else if (animate && main && secondary && main.id === secondary.id && main.id !== foreground?.id) {
            phase = 0
            direction = "split"
            chip = main
        } else {
            main = foreground
            chip = secondary
            return
        }
        nextMain = foreground
        nextChip = secondary
        motion.start()
    }
    onPhaseChanged: if (moving && phase >= contact) main = nextMain
    onForegroundChanged: Qt.callLater(reconcile)
    onSecondaryChanged: Qt.callLater(reconcile)
    onAnimateChanged: Qt.callLater(reconcile)
    Component.onCompleted: Qt.callLater(reconcile)
    readonly property NumberAnimation motion: NumberAnimation {
        target: handoff
        property: "phase"
        from: 0; to: 1
        duration: handoff.direction === "split" ? 450 : 400
        easing.type: Easing.Linear
        onFinished: {
            if (handoff.direction === "merge" && handoff.nextMain?.updated === handoff.foreground?.updated && handoff.foreground?.id === handoff.chip?.id)
                handoff.merging(handoff.foreground, true)
            handoff.main = handoff.nextMain
            handoff.chip = handoff.nextChip
            handoff.direction = ""
            Qt.callLater(handoff.reconcile)
        }
    }
}
