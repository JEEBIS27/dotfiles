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
        {name: "Do nothing", id: "none"}, {name: "Music player", id: "toggleExpandedPlayer"},
        {name: "Control center", id: "toggleControlCenter"}, {name: "Calendar", id: "toggleCalendar"},
        {name: "Clipboard", id: "toggleClipboard"}, {name: "Weather", id: "toggleWeather"},
        {name: "Notifications", id: "toggleNotificationCenter"}
    ]

    function change(key, value) {
        ConfigStore.setValue(key, value)
        ConfigStore.save()
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: 0
        Label {
            text: "Display durations"
            font.pixelSize: 26
            font.bold: true
            Layout.margins: 24
        }
        Repeater {
            model: [
                {key: "edgeHandleDurationMs", title: "Edge handles", hint: "While hovering over the notification or control center handle."},
                {key: "islandAutoHideDelayMs", title: "Island auto-hide & peek", hint: "After the pointer leaves, or when the temporary reveal shortcut is used."},
                {key: "transientCapsuleDurationMs", title: "Workspace, app & level changes", hint: "Workspace dots, app opening or closing, and volume or brightness feedback."},
                {key: "notificationDurationMs", title: "Notifications & completions", hint: "Time in the main Island before moving to notification history."},
                {key: "workingForegroundDurationMs", title: "Work in progress", hint: "Time in the main Island before a running task moves to the small capsule."},
                {key: "trackChangeDurationMs", title: "Track changes", hint: "How long a new song takes priority over other background activities."},
                {key: "bluetoothDetailDurationMs", title: "Bluetooth device details", hint: "Time before the device detail capsule closes automatically."}
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
                        Accessible.name: setting.modelData.title + " in seconds"
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
                    Label { text: "s" }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.splitLineColor }
            }
        }
        Label {
            text: "Behavior"
            font.pixelSize: 22
            font.bold: true
            Layout.margins: 24
        }
        Repeater {
            model: [
                {key: "islandAutoHideEnabled", title: "Auto-hide the idle Island", initial: true},
                {key: "islandShowWorkspaceOnAutoHide", title: "Reveal the Island on workspace changes", initial: true},
                {key: "disableAutoExpandOnTrackChange", title: "Highlight track changes", initial: false, inverted: true}
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
            Label { Layout.fillWidth: true; text: "On Island hover" }
            ComboBox {
                model: ["Do nothing", "Open music player", "Open control center"]
                Accessible.name: "On Island hover"
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
                    text: button === 1 ? "Left click outside clock mode" : button === 2 ? "Middle click" : "Right click"
                }
                ComboBox {
                    model: page.clickActions
                    textRole: "name"
                    valueRole: "id"
                    Accessible.name: clickLabel.text
                    currentIndex: page.clickActions.findIndex(option => option.id === action)
                    displayText: currentIndex < 0 ? action : currentText
                    onActivated: page.change(prefix + "Action", currentValue)
                }
            }
        }
    }
}
