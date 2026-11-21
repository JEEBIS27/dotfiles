import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import IslandBackend

Rectangle {
    id: view
    required property var hub
    required property var player
    required property string track
    required property string artist
    required property string art
    required property bool timerActive
    required property int timerSeconds
    signal openPlayer()
    signal openTimer()
    property string selected: ""
    property bool listing: false
    property double songChanged: 0
    property string lastSong: ""
    readonly property bool playing: !!player && player.isPlaying && !!track
    readonly property string song: playing ? String(player.dbusName) + "|" + artist + "|" + track : ""
    onSongChanged: {
        if (song && lastSong && song !== lastSong && !UserConfig.disableAutoExpandOnTrackChange)
            songChanged = Date.now()
        else if (!song) songChanged = 0
        lastSong = song
    }
    function duration(ms) {
        const s = Math.max(0, Math.floor(ms / 1000))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }
    readonly property var rows: {
        if (!hub) return []
        const live = hub.items.filter(r => !(hub.silent && ["notification","done"].includes(r.kind))
                    && !(["notification","done"].includes(r.kind) && r.updated < hub.lastUnsilenced))
        const music = {id:"media", kind:"music", title:track, body:artist, source:{app:player ? player.identity : ""}, updated:songChanged}
        const changed = playing && songChanged && hub.clock - songChanged < 5000
        if (changed && !hub.silent) live.push(music)
        if (hub.recording) live.push({id:"record", kind:"record", title:"Recording", started:hub.recordingStarted, source:{app:"Tide Island"}})
        if (timerActive) live.push({id:"timer", kind:"timer", title:"Timer", source:{app:"Tide Island"}})
        if (playing && !live.includes(music)) live.push(music)
        const ranks = {needs:0, notification:1, done:1, progress:2, working:3, record:3, timer:3, music:changed && !hub.silent ? 1 : 9}
        return live.sort((a,b) => ranks[a.kind] - ranks[b.kind] || (b.updated || 0) - (a.updated || 0))
    }
    readonly property var current: {
        if (selected) {
            const item = rows.find(r => r.id === selected) || (hub ? hub.history.find(r => r.id === selected) : null)
            if (item) return item
        }
        return rows.length ? rows[0] : null
    }
    readonly property bool detailed: listing || (!!selected && !!current && current.id === selected)
    readonly property var secondary: rows.filter(r => !current || r.id !== current.id)
    readonly property var chip: secondary.find(r => r.kind === "music") || secondary[0] || null
    readonly property bool wanted: !!current || listing || !!(hub && hub.errorText)
    readonly property int detailHeight: listing ? Math.min(310, 60 + rows.length * 42)
        : Math.min(330, Math.max(110, form.implicitHeight + 28))
    onRowsChanged: if (selected && !rows.some(r => r.id === selected) && !hub.history.some(r => r.id === selected)) closeDetails()
    function closeDetails() { selected = ""; listing = false }
    function expand(row) {
        if (!row) return
        listing = false
        if (row.id === "media") { closeDetails(); openPlayer(); return }
        if (row.id === "timer") { closeDetails(); openTimer(); return }
        selected = row.id
    }
    function open(row) {
        if (!row) return
        if (row.kind === "music") {
            if (player && player.canRaise) player.raise()
            else if (player) hub.send({op:"media", app:player.identity, desktop:player.desktopEntry})
        } else if (row.kind === "timer") openTimer()
        else if (row.kind === "record") expand(row)
        else hub.send({op:"open", id:row.id})
    }
    function glyph(kind) {
        return ({needs:"?", done:"✓", progress:"↓", working:"✦", music:"♫", notification:"●", record:"●", timer:"◷"})[kind] || "·"
    }
    function suffix(row) {
        if (!row) return ""
        if (row.kind === "needs") return "Needs you"
        if (row.kind === "progress" && row.value != null) return Math.round(row.value) + "%"
        if (["working","record"].includes(row.kind)) return duration(hub.clock - row.started)
        if (row.kind === "timer") return duration(timerSeconds * 1000)
        return ""
    }
    color: StyleTokens.panel
    radius: detailed ? 26 : height / 2
    clip: true
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: view.open(view.current)
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 6
        spacing: 7
        visible: !view.detailed
        Image {
            visible: view.current && view.current.kind === "music" && view.art !== ""
            source: visible ? view.art : ""
            Layout.preferredHeight: 23; Layout.preferredWidth: 23
            fillMode: Image.PreserveAspectCrop
        }
        Text {
            visible: !view.current || view.current.kind !== "music" || !view.art
            text: view.current ? view.glyph(view.current.kind) : "!"
            color: view.current && view.current.kind === "needs" ? "#ffcb70" : StyleTokens.accent
            font.bold: true
        }
        Text {
            Layout.fillWidth: true
            text: view.hub && view.hub.errorText || (view.current ? (view.current.title === "Needs you" && view.current.body || view.current.title) : "")
            textFormat: Text.PlainText; elide: Text.ElideRight
            font.family: UserConfig.textFontFamily; font.pixelSize: 13
            color: StyleTokens.textPrimary
        }
        Text {
            text: view.suffix(view.current); visible: !!text && !(view.hub && view.hub.errorText)
            color: StyleTokens.textSecondary; font.pixelSize: 11
        }
        IslandButton { text: "⌄"; description: "Expand details"; implicitWidth: 26; implicitHeight: 23; onClicked: view.expand(view.current) }
    }
    ScrollView {
        id: scroll
        visible: view.detailed
        anchors.fill: parent; anchors.margins: 14
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            id: form
            width: scroll.availableWidth
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: view.listing ? "Activities" : view.current ? view.current.source.app + (view.suffix(view.current) ? "  ·  " + view.suffix(view.current) : "") : ""
                    color: StyleTokens.textSecondary; elide: Text.ElideRight; textFormat: Text.PlainText
                    TapHandler { onTapped: if (!view.listing) view.open(view.current) }
                }
                IslandButton { text: "×"; description: "Collapse"; onClicked: view.closeDetails() }
            }
            Repeater {
                model: view.listing ? view.rows : []
                IslandButton {
                    required property var modelData
                    Layout.fillWidth: true; text: view.glyph(modelData.kind) + "   " + modelData.title
                    onClicked: view.expand(modelData)
                }
            }
            ColumnLayout {
                visible: !view.listing && !!view.current
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: view.current ? (view.current.title === "Needs you" && view.current.body || view.current.title) : ""
                    textFormat: Text.PlainText; color: StyleTokens.textPrimary
                    font.bold: true; font.pixelSize: 16; font.family: UserConfig.textFontFamily
                    TapHandler { onTapped: view.open(view.current) }
                }
                Text {
                    Layout.fillWidth: true; visible: !!text; wrapMode: Text.Wrap
                    text: view.current && view.current.title !== "Needs you" ? view.current.body || "" : ""
                    textFormat: Text.PlainText; color: StyleTokens.textSecondary
                    TapHandler { onTapped: view.open(view.current) }
                }
                ProgressBar {
                    Layout.fillWidth: true; visible: !!view.current && view.current.kind === "progress"
                    value: view.current ? (view.current.value || 0) / 100 : 0
                }
                Flow {
                    Layout.fillWidth: true; spacing: 5
                    visible: actionButtons.count > 0
                    Repeater {
                        id: actionButtons
                        model: view.current ? (view.current.actions || []).filter(a => a[0] !== "default") : []
                        IslandButton {
                            required property var modelData
                            text: modelData[1]
                            onClicked: view.hub.send({op:"action", id:view.current.id, value:modelData[0]})
                        }
                    }
                }
                QuestionReply {
                    Layout.fillWidth: true
                    request: view.detailed && !view.listing ? view.current : null
                    hub: view.hub
                    visible: !!token
                }
                IslandButton {
                    visible: !!view.current && view.current.kind === "record"
                    text: "Stop recording"; onClicked: view.hub.toggleRecording()
                }
                Text {
                    visible: !!text; Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: view.hub ? view.hub.errorText : ""; textFormat: Text.PlainText; color: StyleTokens.textSecondary
                }
            }
        }
    }
}
