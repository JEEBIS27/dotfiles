import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TideIsland

ScrollView {
    id: page
    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    readonly property var clickActions: [
        {name: "何もしない", id: "none"}, {name: "音楽プレーヤー", id: "toggleExpandedPlayer"},
        {name: "コントロールセンター", id: "toggleControlCenter"}, {name: "カレンダー", id: "toggleCalendar"},
        {name: "クリップボード", id: "toggleClipboard"}, {name: "天気", id: "toggleWeather"},
        {name: "通知センター", id: "toggleNotificationCenter"}
    ]

    function change(key, value) {
        ConfigStore.setValue(key, value)
        ConfigStore.save()
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: 0
        Label {
            text: "表示時間"
            font.pixelSize: 26
            font.bold: true
            Layout.margins: 24
        }
        Repeater {
            model: [
                {key: "edgeHandleDurationMs", title: "画面上端のハンドル", hint: "通知・コントロールセンターのハンドルにマウスを重ねたときの表示時間。"},
                {key: "islandAutoHideDelayMs", title: "Islandの自動非表示・一時表示", hint: "マウスが離れた後、または一時表示のショートカットを使ったときの表示時間。"},
                {key: "transientCapsuleDurationMs", title: "ワークスペース・アプリ・音量など", hint: "ワークスペースのドット、アプリアイコン列、音量や明るさの一時表示。"},
                {key: "notificationDurationMs", title: "通知・完了", hint: "通知履歴に移るまでの表示時間。"},
                {key: "workingForegroundDurationMs", title: "作業中", hint: "実行中のタスクが小さいカプセルへ移るまでの時間。"},
                {key: "trackChangeDurationMs", title: "曲の切り替え", hint: "曲の切り替えを優先して表示する時間。"},
                {key: "bluetoothDetailDurationMs", title: "Bluetooth機器の詳細", hint: "機器の詳細を自動で閉じるまでの時間。"}
            ]
            ColumnLayout {
                id: setting
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 9
                    Layout.bottomMargin: 9
                    spacing: 16
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Label { text: setting.modelData.title; font.bold: true }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: Theme.secondaryTextColor
                            text: setting.modelData.hint
                        }
                    }
                    SpinBox {
                        id: duration
                        objectName: setting.modelData.key
                        Accessible.name: setting.modelData.title + "（秒）"
                        from: backend.minimumDuration
                        to: backend.durationLimits[setting.modelData.key]
                        value: backend.durations[setting.modelData.key]
                        editable: true
                        stepSize: 250
                        validator: DoubleValidator {
                            bottom: duration.from / 1000
                            top: duration.to / 1000
                            decimals: 3
                            locale: duration.locale.name
                            notation: DoubleValidator.StandardNotation
                        }
                        textFromValue: (ms, locale) => (ms / 1000).toLocaleString(locale, "f", 3).replace(/0+$/, "").replace(/[.,]$/, "")
                        valueFromText: (input, locale) => Math.round(Number.fromLocaleString(locale, input) * 1000)
                        onValueModified: page.change(setting.modelData.key, value)
                    }
                    Label { text: "秒" }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.splitLineColor }
            }
        }
        Label {
            text: "操作"
            font.pixelSize: 22
            font.bold: true
            Layout.margins: 24
        }
        Repeater {
            model: [
                {key: "islandAutoHideEnabled", title: "待機中のIslandを自動で隠す", initial: true},
                {key: "islandShowWorkspaceOnAutoHide", title: "ワークスペース切替時にIslandを表示する", initial: true},
                {key: "disableAutoExpandOnTrackChange", title: "曲の切り替えを強調する", initial: false, inverted: true}
            ]
            SwitchDelegate {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                text: modelData.title
                checked: Boolean(ConfigStore.value(modelData.key, modelData.initial)) !== Boolean(modelData.inverted)
                onToggled: page.change(modelData.key, checked !== Boolean(modelData.inverted))
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 24
            Label { Layout.fillWidth: true; text: "Islandにマウスを重ねたとき" }
            ComboBox {
                model: ["何もしない", "音楽プレーヤーを開く", "コントロールセンターを開く"]
                Accessible.name: "Islandにマウスを重ねたとき"
                currentIndex: ConfigStore.value("hoverExpandAction", 1)
                onActivated: index => page.change("hoverExpandAction", index)
            }
        }
        Repeater {
            // Older configurations may assign the same button to two actions.
            // Match the shell's first-match order and omit unreachable bindings.
            model: [
                {slot: "Primary", button: 1, action: "toggleExpandedPlayer"},
                {slot: "Secondary", button: 3, action: "toggleControlCenter"},
                {slot: "Middle", button: 2, action: "toggleClipboard"}
            ]
            RowLayout {
                required property var modelData
                required property int index
                readonly property string prefix: "dynamicIsland" + modelData.slot
                readonly property int button: ConfigStore.value(prefix + "Button", modelData.button)
                readonly property string action: ConfigStore.value(prefix + "Action", modelData.action)
                visible: index === 0 || (button !== ConfigStore.value("dynamicIslandPrimaryButton", 1)
                    && (index === 1 || button !== ConfigStore.value("dynamicIslandSecondaryButton", 3)))
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 12
                Label {
                    id: clickLabel
                    Layout.fillWidth: true
                    text: button === 1 ? "時計表示以外で左クリック" : button === 2 ? "中央クリック" : "右クリック"
                }
                ComboBox {
                    model: page.clickActions
                    textRole: "name"
                    valueRole: "id"
                    Accessible.name: clickLabel.text
                    currentIndex: page.clickActions.findIndex(option => option.id === action)
                    displayText: currentIndex < 0 ? "カスタム" : currentText
                    onActivated: page.change(prefix + "Action", currentValue)
                }
            }
        }
    }
}
