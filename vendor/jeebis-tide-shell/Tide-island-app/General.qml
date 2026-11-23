import TideIsland 1.0
import QtQuick.Controls
import QtQuick

PagePanel {
    id: root

    function intValue(key, fallback) {
        return String(ConfigStore.value(key, fallback))
    }

    function saveInt(key, value, fallback, minimumValue, maximumValue) {
        if (String(value).trim().length === 0) {
            return fallback
        }

        const parsedValue = Number(value)
        if (isNaN(parsedValue)) {
            return fallback
        }

        const roundedValue = Math.min(maximumValue, Math.max(minimumValue, Math.round(parsedValue)))
        ConfigStore.setValue(key, roundedValue)
        ConfigStore.save()
        return roundedValue
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        interactive: false

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: function(event) {
                const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 80
                const maxY = Math.max(0, scroller.contentHeight - scroller.height)
                scroller.contentY = Math.max(0, Math.min(maxY, scroller.contentY - rawDelta))
                event.accepted = true
            }
        }

        Item {
            id: content
            width: scroller.width
            height: weatherPanel.y + weatherPanel.height + 40

            Text {
                id: title
                font.family: Theme.titleFontFamily
                text: "外観と天気"
                color: Theme.textColor
                font.pixelSize: 30
                x: 60
                y: 50
            }

            Text {
                id: apperanceTitle
                text: "Islandの外観"
                anchors.top: title.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            Rectangle {
                id: apperance
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor

                anchors.top: apperanceTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: apperanceColumn.implicitHeight + 36

                Column {
                    id: apperanceColumn

                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ConfigRow {
                        title: "Islandの幅"
                        description: "時計を表示するときの幅"
                        keyName: "islandWidth"
                        fallbackText: "140"
                        numeric: true
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Islandの高さ"
                        description: "時計を表示するときの高さ"
                        keyName: "islandHeight"
                        fallbackText: "38"
                        numeric: true
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "コンパクト表示の枠幅"
                        description: "時計・一時表示・小さいカプセル（0＝枠なし）"
                        keyName: "islandFrameWidth"
                        fallbackText: "1"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 8
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "詳細表示の枠幅"
                        description: "展開したIslandの枠。初期値はNiriと同じ4（0＝枠なし）"
                        keyName: "islandExpandedFrameWidth"
                        fallbackText: "4"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 8
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "背景の不透明度"
                        description: "Islandの背景の濃さ（0＝透明、100＝不透明）"
                        keyName: "islandBackgroundOpacity"
                        fallbackText: "60"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    Item {
                        width: parent.width
                        height: Math.max(49, blurLabels.implicitHeight)

                        Column {
                            id: blurLabels
                            anchors.left: parent.left
                            anchors.right: blurSwitch.left
                            anchors.rightMargin: 18
                            anchors.top: parent.top
                            spacing: 5

                            Text {
                                text: "背景のぼかし"
                                font.family: Theme.textFontFamily
                                font.pixelSize: 18
                                color: Theme.textColor
                            }
                            Text {
                                width: parent.width
                                text: "Islandと詳細パネルの背後をぼかす"
                                font.family: Theme.textFontFamily
                                font.pixelSize: 14
                                color: Theme.subtleTextColor
                                wrapMode: Text.Wrap
                            }
                        }

                        Switch {
                            id: blurSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 28
                            padding: 0
                            checked: {
                                const value = ConfigStore.value("islandBlurEnabled", true)
                                return typeof value === "boolean" ? value : true
                            }
                            Accessible.name: "背景のぼかし"
                            onToggled: {
                                ConfigStore.setValue("islandBlurEnabled", checked)
                                ConfigStore.save()
                            }

                            indicator: Rectangle {
                                width: 36
                                height: 22
                                y: (blurSwitch.height - height) / 2
                                radius: 11
                                color: blurSwitch.checked ? Theme.accentColor : Theme.controlPressedColor
                                border.width: blurSwitch.visualFocus ? 2 : 0
                                border.color: Theme.focusBorderColor

                                Rectangle {
                                    x: blurSwitch.checked ? 16 : 2
                                    y: 2
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: "#ffffff"
                                    Behavior on x {
                                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }

                    SplitLine { width: parent.width }

                    ClockFormatRow { width: parent.width }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "画面上端の予約領域"
                        description: "Island用にウィンドウの配置から除外する高さ"
                        keyName: "islandExclusiveZone"
                        fallbackText: "45"
                        numeric: true
                        minimumValue: 0
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "上端からの余白"
                        description: "画面上端からIslandまでの距離"
                        keyName: "islandTopMargin"
                        fallbackText: "4"
                        numeric: true
                        minimumValue: 0
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Islandの横位置"
                        description: "左端を0、右端を100とした位置"
                        keyName: "islandPositionX"
                        fallbackText: "50"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }
                }
            }

            Text {
                id: customPageTitle
                text: "スワイプで表示する項目"
                anchors.top: apperance.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            CustomPage {
                id: customPagePanel
                anchors.top: customPageTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: implicitHeight
            }

            Text {
                id: weatherTitle
                text: "天気"
                anchors.top: customPagePanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            WeatherSettings {
                id: weatherPanel
                anchors.top: weatherTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: implicitHeight
            }

        }
    }

    component SplitLine: Rectangle {
        height: 1
        color: Theme.splitLineColor
    }

    component ConfigRow: Item {
        id: row

        property string title: ""
        property string description: ""
        property string keyName: ""
        property string fallbackText: ""
        property bool numeric: false
        property int minimumValue: 1
        property int maximumValue: 1000

        height: 49

        Text {
            id: rowTitle
            text: row.title
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: row.description
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            anchors.left: rowTitle.left
            color: Theme.subtleTextColor
        }

        ConfigTextField {
            id: field
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: row.numeric ? 100 : 230
            height: 36
            placeholderText: row.fallbackText
            inputMethodHints: row.numeric ? Qt.ImhDigitsOnly : Qt.ImhNone
            validator: row.numeric ? intValidator : null

            Component.onCompleted: {
                text = root.intValue(row.keyName, Number(row.fallbackText))
            }

            onAccepted: row.commit()
            onEditingFinished: row.commit()
        }

        IntValidator {
            id: intValidator
            bottom: row.minimumValue
            top: row.maximumValue
        }

        function commit() {
            if (numeric) {
                field.text = String(root.saveInt(row.keyName, field.text, Number(row.fallbackText), row.minimumValue, row.maximumValue))
            }
        }
    }

    component ClockFormatRow: Item {
        id: clockRow

        property string selectedFormat: String(ConfigStore.value("clockFormat", "12")) === "24" ? "24" : "12"

        height: 49

        Text {
            id: clockTitle
            text: "時刻の表示形式"
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: "12時間表示または24時間表示"
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: clockTitle.bottom
            anchors.topMargin: 5
            anchors.left: clockTitle.left
            color: Theme.subtleTextColor
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: ["12", "24"]

                Rectangle {
                    id: formatButton
                    readonly property bool selected: clockRow.selectedFormat === modelData

                    width: 82
                    height: 36
                    radius: 7
                    color: selected ? Theme.cardBgColor
                                    : formatMouse.pressed ? Theme.controlPressedColor
                                                          : Theme.componentBgColor
                    border.width: 1
                    border.color: Theme.inputBorderColor

                    Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData + "時間"
                        color: formatButton.selected ? Theme.textColor : Theme.secondaryTextColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                        font.weight: formatButton.selected ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: formatMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            clockRow.selectedFormat = modelData
                            ConfigStore.setValue("clockFormat", modelData)
                            ConfigStore.save()
                        }
                    }
                }
            }
        }
    }
}
