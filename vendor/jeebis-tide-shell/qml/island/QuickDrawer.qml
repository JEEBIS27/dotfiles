import QtQuick
import QtQuick.Controls
import IslandBackend

Item {
    id: drawer
    required property var control
    required property var hub
    property string menu: ""
    readonly property var tiles: [
        ["silent","Silent","\uf1f6"], ["night","Night","\uf186"], ["awake","Awake","\uf0f4"], ["timer","Timer","\uf252"],
        ["capture","Capture","\uf125"], ["record","Record","\uf03d"], ["audio","Audio out","\uf028"], ["video","Display out","\uf108"]
    ]
    readonly property var choices: {
        if (menu === "awake") return [
            {id:"0", label:"Off", icon:"\uf011"},
            {id:"30", label:"30 min", icon:"\uf017"},
            {id:"60", label:"1 hour", icon:"\uf252"},
            {id:"-1", label:"Until turned off", icon:"\uf0c1"}
        ]
        if (menu === "capture") return [
            {id:"region", label:"Region", icon:"\uf125"},
            {id:"window", label:"Window", icon:"\uf2d0"},
            {id:"screen", label:"Screen", icon:"\uf108"}
        ]
        if (menu === "audio" || menu === "video") return hub && hub.outputKind === menu ? hub.outputs : []
        return []
    }
    function itemAt(index) { return buttons.itemAt(index) }
    function active(key) {
        return (key === "silent" && control.focusEnabled) || (key === "night" && control.nightLightEnabled)
            || (key === "awake" && hub && hub.awake) || (key === "record" && hub && (hub.recording || hub.startingRecording))
    }
    function activate(key) {
        if (key === "silent") control.toggleFocus()
        else if (key === "night") control.toggleNightLight()
        else if (key === "timer") control.timerRequested()
        else if (key === "record") { hub.toggleRecording(); control.dismissRequested() }
        else {
            menu = key
            if (key === "audio" || key === "video") {
                hub.outputKind = ""; hub.outputs = []; hub.send({op:"outputs", kind:key})
            }
        }
    }
    function choose(value) {
        if (menu === "awake") hub.awakeUntil = Number(value) <= 0 ? Number(value) : Date.now() + Number(value) * 60000
        else if (menu === "capture") { hub.send({op:"capture", value:value}); control.dismissRequested(); return }
        else hub.send({op:"choose", kind:menu, value:value})
        menu = ""
    }
    Grid {
        visible: !drawer.menu
        anchors.fill: parent; columns: 4; rowSpacing: 4; columnSpacing: 4
        Repeater {
            id: buttons
            model: drawer.tiles
            delegate: AbstractButton {
                id: tile
                required property var modelData
                readonly property bool selected: drawer.active(modelData[0])
                width: (drawer.width - 12) / 4; height: (drawer.height - 4) / 2
                Accessible.name: modelData[1]; hoverEnabled: true
                onClicked: drawer.activate(modelData[0])
                background: Rectangle {
                    radius: 13
                    color: tile.selected ? StyleTokens.accent : tile.hovered ? StyleTokens.moduleHover : StyleTokens.module
                    border.width: tile.visualFocus ? 1 : 0; border.color: StyleTokens.textPrimary
                }
                contentItem: Column {
                    spacing: 2
                    topPadding: Math.max(2, (tile.height - 33) / 2)
                    Text {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter; text: tile.modelData[2]
                        font.family: UserConfig.iconFontFamily; font.pixelSize: 16
                        color: tile.selected ? "#15181c" : StyleTokens.textPrimary
                    }
                    Text {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter; text: tile.modelData[1]
                        font.family: UserConfig.textFontFamily; font.pixelSize: 11
                        color: tile.selected ? "#15181c" : StyleTokens.textSecondary
                    }
                }
            }
        }
    }
    Column {
        visible: !!drawer.menu
        anchors.fill: parent; spacing: 5
        Row {
            spacing: 7
            IslandButton { text: "‹"; description: "Back"; onClicked: drawer.menu = "" }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ({awake:"Keep awake",capture:"Capture",audio:"Audio output",video:"Display for the active window"})[drawer.menu] || ""
                color: StyleTokens.textPrimary; font.bold: true
            }
        }
        ListView {
            id: choiceList
            width: parent.width
            height: Math.max(0, drawer.height - y)
            orientation: ListView.Horizontal
            clip: true
            spacing: 4
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
            model: drawer.choices
            delegate: AbstractButton {
                id: choice
                required property var modelData
                readonly property bool chosen: !!modelData.selected
                width: Math.max(88, (choiceList.width - (Math.min(4, choiceList.count) - 1) * choiceList.spacing)
                    / Math.max(1, Math.min(4, choiceList.count)))
                height: Math.max(0, choiceList.height - 8)
                text: modelData.label
                Accessible.name: text
                Accessible.selected: chosen
                hoverEnabled: true
                ToolTip.visible: hovered && label.truncated
                ToolTip.text: text
                onClicked: drawer.choose(modelData.id)
                background: Rectangle {
                    radius: 13
                    color: choice.chosen ? StyleTokens.accent : choice.hovered ? StyleTokens.moduleHover : StyleTokens.module
                    border.width: choice.visualFocus ? 1 : 0
                    border.color: StyleTokens.textPrimary
                }
                contentItem: Column {
                    spacing: 4
                    topPadding: Math.max(0, (height - choiceGlyph.height - label.height - spacing) / 2)
                    Text {
                        id: choiceGlyph
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: choice.modelData.icon || (drawer.menu === "audio" ? "\uf028" : "\uf108")
                        font.family: UserConfig.iconFontFamily
                        font.pixelSize: 19
                        color: choice.chosen ? "#15181c" : StyleTokens.textPrimary
                    }
                    Text {
                        id: label
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: choice.text
                        font.family: UserConfig.textFontFamily
                        font.pixelSize: 11
                        color: choice.chosen ? "#15181c" : StyleTokens.textPrimary
                    }
                }
            }
            Text {
                visible: !parent.count && !!drawer.menu
                text: drawer.hub && drawer.hub.errorText || (drawer.hub && drawer.hub.outputKind === drawer.menu ? "No outputs available" : "Loading…")
                color: StyleTokens.textSecondary
            }
        }
    }
}
