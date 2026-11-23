pragma Singleton
import QtQuick
import TideIsland

QtObject {
    readonly property color totalBgColor: StyleTokens.panel
    readonly property color componentBgColor: StyleTokens.module
    readonly property color cardBgColor: StyleTokens.module
    readonly property color inputBgColor: StyleTokens.panel
    readonly property color inputHoverBgColor: StyleTokens.moduleHover
    readonly property color inputBorderColor: StyleTokens.inputBorder
    readonly property color inputHoverBorderColor: StyleTokens.accent
    readonly property color focusBorderColor: StyleTokens.accent
    readonly property color focusRingColor: StyleTokens.accentSoft
    readonly property color textColor: StyleTokens.textPrimary
    readonly property color secondaryTextColor: Qt.tint(StyleTokens.textPrimary, Qt.alpha(StyleTokens.panel, 0.12))
    readonly property color subtleTextColor: Qt.tint(StyleTokens.textPrimary, Qt.alpha(StyleTokens.panel, 0.12))
    readonly property color splitLineColor: StyleTokens.surfaceBorder
    readonly property color buttonColor: StyleTokens.accent
    readonly property color buttonHoverColor: StyleTokens.accent
    readonly property color buttonPressedColor: StyleTokens.accentPressed
    readonly property color buttonTextColor: StyleTokens.panel
    readonly property color mutedButtonColor: StyleTokens.secondaryButton
    readonly property color mutedButtonHoverColor: StyleTokens.moduleHover
    readonly property color mutedButtonTextColor: StyleTokens.textPrimary
    readonly property color controlHoverColor: StyleTokens.moduleHover
    readonly property color controlPressedColor: StyleTokens.switchOff
    readonly property color accentColor: StyleTokens.accent
    readonly property color selectedColor: StyleTokens.accent
    readonly property bool darkMode: totalBgColor.hslLightness < 0.5
    readonly property int animationDuration: 160
    readonly property string textFontFamily: String(ConfigStore.value("textFontFamily", "Sans Serif"))
    readonly property string titleFontFamily: textFontFamily
}
