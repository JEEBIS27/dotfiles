import QtQuick
import Quickshell
import IslandBackend

Item {
    id: queue
    required property bool active
    required property int displayDuration
    signal dismissRequested()

    readonly property int slotWidth: 26
    readonly property int spacing: 4
    readonly property int motionDuration: opening ? 400 : 540
    readonly property int pitch: slotWidth + spacing
    // The moving slot gives up its space during contact. Its delegate stays
    // alive until the satellite has finished rebounding beyond the row.
    readonly property real slotFraction: movingApp ? 1 - smoothPhase(separation, 0.12, 0.78) : 1
    readonly property int movingIndex: movingApp ? indexOf(movingApp) : -1
    readonly property real occupiedSlots: icons.count - (movingIndex >= 0 ? 1 - slotFraction : 0)
    function smoothPhase(value, start, end) {
        const t = Math.max(0, Math.min(1, (value - start) / (end - start)))
        return t * t * (3 - 2 * t)
    }
    readonly property real preferredWidth: Math.max(44, 24 + occupiedSlots * pitch - spacing)
    property var pending: []
    property string movingApp: ""
    property bool opening: false
    property real separation: 0
    readonly property var movingSlot: slots.itemAt(movingIndex)
    readonly property real slotX: movingSlot ? row.x + movingSlot.x + movingSlot.width / 2 - spacing * slotFraction / 2 : width / 2
    readonly property string movingIcon: movingApp ? Quickshell.iconPath(
        DesktopEntries.heuristicLookup(movingApp)?.icon || movingApp, true) : ""
    visible: active
    clip: true

    onActiveChanged: {
        if (active) return
        travel.stop()
        movingApp = ""
        stage.stop()
        dismiss.stop()
        pending = []
        icons.clear()
    }

    function enqueue(appId, opened, before) {
        dismiss.stop()
        const first = !stage.running && !travel.running
        pending.push({appId, opened, before: Array.from(before)})
        if (first) prepare()
    }

    function indexOf(appId) {
        for (let index = 0; index < icons.count; ++index) {
            if (icons.get(index).appId === appId) return index
        }
        return -1
    }

    function prepare() {
        if (pending.length === 0) {
            if (icons.count === 0) dismissRequested()
            else dismiss.restart()
            return
        }

        const before = pending[0].before
        for (let index = icons.count - 1; index >= 0; --index) {
            if (!before.includes(icons.get(index).appId)) icons.remove(index)
        }
        for (const appId of before) {
            if (indexOf(appId) < 0) icons.append({appId})
        }
        stage.interval = 100
        stage.restart()
    }

    function applyChange() {
        const {appId, opened} = pending.shift()
        opening = opened
        separation = opened ? 1 : 0
        movingApp = appId
        const index = indexOf(appId)
        if (opened && index < 0) {
            icons.append({appId})
            row.requestedOffset = Math.max(0, icons.count * pitch - row.width)
        } else if (!opened && index >= 0) {
            row.requestedOffset = Math.max((index + 1) * pitch - row.width, Math.min(index * pitch, row.offset))
        }
        travel.to = opened ? 0 : 1
        travel.start()
    }

    NumberAnimation {
        id: travel
        target: queue
        property: "separation"
        duration: queue.motionDuration
        easing.type: Easing.Linear
        onFinished: {
            const index = queue.indexOf(queue.movingApp)
            if (!queue.opening && index >= 0) icons.remove(index)
            queue.movingApp = ""
            queue.prepare()
        }
    }

    ListModel { id: icons }
    Timer {
        id: stage
        onTriggered: queue.applyChange()
    }
    Timer {
        id: dismiss
        interval: queue.displayDuration
        onTriggered: queue.dismissRequested()
    }

    Item {
        id: row
        property real requestedOffset: 0
        readonly property real offset: Math.min(Math.max(0, requestedOffset),
            Math.max(0, queue.occupiedSlots * queue.pitch - width))
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - 24 + queue.spacing, queue.occupiedSlots * queue.pitch))
        anchors.horizontalCenterOffset: queue.spacing / 2
        height: parent.height
        clip: true
        Repeater {
            id: slots
            model: icons
            delegate: Item {
                id: slot
                required property int index
                required property string appId
                readonly property var entry: DesktopEntries.heuristicLookup(appId)
                // Layout every neighbor from the same contact phase as the surface,
                // including during removal of a slot in the middle of the row.
                x: (index - (queue.movingIndex >= 0 && index > queue.movingIndex
                    ? 1 - queue.slotFraction : 0)) * queue.pitch - row.offset
                width: queue.pitch * (index === queue.movingIndex ? queue.slotFraction : 1)
                height: row.height
                opacity: index === queue.movingIndex ? 0 : 1
                Accessible.name: entry?.name || appId
                QueueAppIcon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -queue.spacing / 2
                    width: 20
                    height: 20
                    iconSource: Quickshell.iconPath(slot.entry?.icon || slot.appId, true)
                }
            }
        }
    }
}
