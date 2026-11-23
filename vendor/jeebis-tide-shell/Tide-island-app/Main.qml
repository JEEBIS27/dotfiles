import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import TideIsland

ApplicationWindow {
    id: window
    property bool showLockSettings: false
    property int section: showLockSettings ? 3 : 0
    readonly property var sections: ["表示時間と操作", "外観", "フォント", "ロック画面"]
    visible: true
    width: 920
    height: 700
    minimumWidth: 580
    minimumHeight: 400
    title: "Jeebis Island 設定"
    color: Theme.totalBgColor
    font.family: Theme.textFontFamily
    palette.window: Theme.totalBgColor
    palette.windowText: Theme.textColor
    palette.base: Theme.inputBgColor
    palette.text: Theme.textColor
    palette.button: Theme.componentBgColor
    palette.buttonText: Theme.textColor
    palette.highlight: Theme.selectedColor
    palette.highlightedText: Theme.buttonTextColor

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Frame {
            visible: window.width >= 760
            Layout.fillHeight: true
            Layout.preferredWidth: 210
            padding: 14
            background: Rectangle { color: Theme.componentBgColor }
            ColumnLayout {
                anchors.fill: parent
                spacing: 5
                Label {
                    text: "Jeebis Island"
                    font.pixelSize: 23
                    font.bold: true
                    Layout.topMargin: 12
                    Layout.bottomMargin: 24
                }
                Repeater {
                    model: window.sections
                    ItemDelegate {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        text: modelData
                        highlighted: window.section === index
                        onClicked: window.section = index
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            ComboBox {
                visible: window.width < 760
                Layout.fillWidth: true
                model: window.sections
                currentIndex: window.section
                onActivated: index => window.section = index
            }
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: window.section
                TimingSettings {}
                Item { General {} }
                Item { FontSettings {} }
                Item { LockScreenSettings {} }
            }
            Label {
                visible: ConfigStore.errorString.length > 0
                Layout.fillWidth: true
                padding: 12
                wrapMode: Text.Wrap
                color: StyleTokens.error
                text: ConfigStore.errorString
            }
        }
    }
}
