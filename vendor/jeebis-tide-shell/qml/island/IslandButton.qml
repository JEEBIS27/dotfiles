import QtQuick
import QtQuick.Controls
import IslandBackend

Button {
    id: button
    property color surfaceColor: StyleTokens.module
    property bool marked: false
    property string description: text
    implicitHeight: 28
    implicitWidth: Math.max(28, Math.min(200, label.implicitWidth + 20))
    padding: 4
    opacity: enabled ? 1 : 0.45
    hoverEnabled: true
    Accessible.name: description
    ToolTip.visible: hovered && description !== text
    ToolTip.text: description
    background: Rectangle {
        radius: height / 2
        color: button.marked ? StyleTokens.accent : button.down || button.hovered ? StyleTokens.moduleHover : button.surfaceColor
        border.width: button.visualFocus ? 1 : 0
        border.color: StyleTokens.textPrimary
    }
    contentItem: Text {
        id: label
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: button.text
        color: StyleTokens.textPrimary
        font.family: UserConfig.textFontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }
}
