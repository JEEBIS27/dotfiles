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
    readonly property int motionDuration: 380
    readonly property int preferredWidth: Math.max(44, 24 + icons.count * (slotWidth + spacing) - spacing)
    property var pending: []
    property string movingApp: ""
    property bool opening: false
    property real separation: 0
    readonly property var movingSlot: row.currentItem
    readonly property real slotX: movingSlot ? row.x + movingSlot.x - row.contentX + slotWidth / 2 : width / 2
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
        movingApp = appId
        const index = indexOf(appId)
        if (opened && index < 0) {
            icons.append({appId})
            Qt.callLater(row.positionViewAtEnd)
        } else if (!opened && index >= 0) {
            row.positionViewAtIndex(index, ListView.Contain)
        }
        separation = opened ? 1 : 0
        travel.to = opened ? 0 : 1
        travel.start()
    }

    NumberAnimation {
        id: travel
        target: queue
        property: "separation"
        duration: queue.motionDuration
        easing.type: Easing.InOutCubic
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

    ListView {
        id: row
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - 24, queue.preferredWidth - 24))
        height: parent.height
        orientation: ListView.Horizontal
        spacing: queue.spacing
        interactive: false
        clip: true
        model: icons
        currentIndex: queue.indexOf(queue.movingApp)
        delegate: Item {
            id: slot
            required property string appId
            readonly property var entry: DesktopEntries.heuristicLookup(appId)
            width: queue.slotWidth
            height: row.height
            opacity: appId === queue.movingApp ? 0 : 1
            Accessible.name: entry?.name || appId
            QueueAppIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                iconSource: Quickshell.iconPath(slot.entry?.icon || slot.appId, true)
            }
        }
        displaced: Transition {
            NumberAnimation { property: "x"; duration: queue.motionDuration; easing.type: Easing.OutCubic }
        }
    }
}
