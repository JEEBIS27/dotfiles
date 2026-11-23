import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import IslandBackend
import "../design"

Button {
    id: button
    property real surfaceOpacity: 1
    property real labelOpacity: 1
    property real labelBlur: 0
    property color outlineColor: StyleTokens.surfaceBorder
    property color surfaceColor: StyleTokens.module
    readonly property real surfaceRadius: Math.min(outsideFrame ? height / 2 : 15, width / 2, height / 2)
    property bool outsideFrame: false
    property real capsuleFrameWidth: 4
    property real pixelRatio: Screen.devicePixelRatio
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
    background: IslandSurface {
        opacity: button.surfaceOpacity
        radius: button.surfaceRadius
        color: button.marked ? StyleTokens.accent : button.down || button.hovered ? StyleTokens.moduleHover : button.surfaceColor
        outsideFrame: button.outsideFrame
        pixelRatio: button.pixelRatio
        frameWidth: button.outsideFrame ? button.capsuleFrameWidth : button.visualFocus ? 2 : 1
        frameColor: button.visualFocus ? StyleTokens.accent : button.outlineColor
    }
    contentItem: Text {
        id: label
        opacity: button.labelOpacity
        layer.enabled: button.labelBlur > 0.01
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 8; blur: button.labelBlur }
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
