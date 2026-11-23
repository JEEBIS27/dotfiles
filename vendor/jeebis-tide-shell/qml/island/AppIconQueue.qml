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
    readonly property int motionDuration: 240
    readonly property int preferredWidth: Math.max(44, 24 + Math.max(icons.count, heldCount) * (slotWidth + spacing) - spacing)
    property int heldCount: 0
    property bool applyingChange: false
    property var pending: []
    visible: active
    clip: true

    onActiveChanged: {
        if (active) return
        stage.stop()
        dismiss.stop()
        pending = []
        heldCount = 0
        icons.clear()
    }

    function enqueue(appId, opened, before) {
        dismiss.stop()
        const first = !stage.running
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
        applyingChange = false
        heldCount = 0
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
        applyingChange = true
        const {appId, opened} = pending.shift()
        const index = indexOf(appId)
        if (opened && index < 0) {
            icons.append({appId})
            Qt.callLater(row.positionViewAtEnd)
        } else if (!opened && index >= 0) {
            row.positionViewAtIndex(index, ListView.Contain)
            heldCount = icons.count
            icons.remove(index)
        }
        stage.interval = motionDuration
        stage.restart()
    }

    ListModel { id: icons }
    Timer {
        id: stage
        onTriggered: {
            if (!queue.applyingChange) queue.applyChange()
            else queue.prepare()
        }
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
        delegate: Item {
            id: slot
            required property string appId
            property real motionOffset: 0
            transform: Translate { x: slot.motionOffset }
            readonly property var entry: DesktopEntries.heuristicLookup(appId)
            width: queue.slotWidth
            height: row.height
            Accessible.name: entry?.name || appId
            Rectangle {
                anchors.centerIn: parent
                width: 17
                height: 14
                radius: 3
                color: "transparent"
                border.color: StyleTokens.textPrimary
                visible: icon.status !== Image.Ready
                Rectangle {
                    x: 1
                    y: 4
                    width: parent.width - 2
                    height: 1
                    color: parent.border.color
                }
            }
            Image {
                id: icon
                anchors.centerIn: parent
                visible: status === Image.Ready
                width: 20
                height: width
                source: Quickshell.iconPath(slot.entry?.icon || slot.appId, "application-x-executable")
            }
        }
        add: Transition {
            enabled: queue.applyingChange
            NumberAnimation { property: "motionOffset"; from: 10; to: 0; duration: queue.motionDuration; easing.type: Easing.OutCubic }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: queue.motionDuration }
            NumberAnimation { property: "scale"; from: 0.55; to: 1; duration: queue.motionDuration; easing.type: Easing.OutCubic }
        }
        remove: Transition {
            enabled: queue.applyingChange
            NumberAnimation { property: "motionOffset"; to: 12; duration: queue.motionDuration; easing.type: Easing.InCubic }
            NumberAnimation { property: "opacity"; to: 0; duration: queue.motionDuration }
            NumberAnimation { property: "scale"; to: 0.55; duration: queue.motionDuration; easing.type: Easing.InCubic }
        }
        displaced: Transition {
            NumberAnimation { property: "x"; duration: queue.motionDuration; easing.type: Easing.OutCubic }
        }
    }
}
