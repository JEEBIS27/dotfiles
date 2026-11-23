import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import IslandBackend

ColumnLayout {
    id: form
    required property var request
    required property var hub
    signal editingRequested()
    readonly property string token: request ? request.token || "" : ""
    readonly property bool japanese: Qt.locale().name.startsWith("ja")
    readonly property bool editorWindowActive: Window.active
    property string option: ""
    property bool restoring: false
    property bool editorFocusPending: false
    spacing: 10

    onTokenChanged: {
        editorFocusPending = false
        restoring = true
        const draft = hub && hub.drafts[token]
        option = draft ? draft.option : ""
        editor.text = draft ? draft.text : ""
        restoring = false
    }
    onEditorWindowActiveChanged: focusEditor()
    function focusEditor() {
        if (editorWindowActive && editorFocusPending) {
            editorFocusPending = false
            editor.forceActiveFocus()
        }
    }
    function remember() {
        if (!restoring && token && hub)
            hub.drafts[token] = {option: option, text: editor.text}
    }
    function submit() {
        if (!token || editor.inputMethodComposing || (!option && !editor.text.trim())) return
        hub.send({op:"reply", id:request.id, token:token, option:option,
                  choice:!editor.text.trim(), value:editor.text.trim() ? editor.text : option})
    }

    Flow {
        Layout.fillWidth: true
        visible: choices.count > 0
        spacing: 6
        Repeater {
            id: choices
            model: form.request ? form.request.choices || [] : []
            delegate: AbstractButton {
                id: suggestion
                required property string modelData
                readonly property bool chosen: form.option === modelData
                width: Math.min(parent.width, answerLabel.implicitWidth + 22)
                height: Math.max(30, answerLabel.implicitHeight + 10)
                hoverEnabled: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData; Accessible.checked: chosen
                onClicked: {
                    form.option = chosen ? "" : modelData
                    form.remember()
                }
                contentItem: Text {
                    id: answerLabel
                    text: (suggestion.chosen ? "✓  " : "") + suggestion.modelData
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    font.family: UserConfig.textFontFamily; font.pixelSize: 13
                    color: StyleTokens.textPrimary
                }
                background: Rectangle {
                    radius: 14
                    color: suggestion.chosen || suggestion.hovered ? StyleTokens.moduleHover : StyleTokens.panel
                    border.color: suggestion.chosen || suggestion.visualFocus ? StyleTokens.textPrimary : StyleTokens.inputBorder
                }
            }
        }
    }

    ScrollView {
        id: field
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(104, Math.max(46, editor.contentHeight + 20))
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        background: Rectangle {
            radius: 11; color: StyleTokens.input
            border.color: editor.activeFocus ? StyleTokens.textSecondary : StyleTokens.inputBorder
        }
        TextArea {
            id: editor
            leftPadding: 12; rightPadding: 12; topPadding: 9; bottomPadding: 9
            font.family: UserConfig.textFontFamily; font.pixelSize: 14
            placeholderText: choices.count > 0 ? (form.japanese ? "その他" : "Something else")
                : (form.japanese ? "回答を入力" : "Write a response")
            placeholderTextColor: StyleTokens.textMuted
            color: StyleTokens.textPrimary
            Accessible.name: placeholderText
            selectByMouse: true; wrapMode: TextEdit.Wrap
            background: null
            onTextChanged: form.remember()
            onPressed: {
                form.editorFocusPending = true
                form.editingRequested()
                form.focusEditor()
            }
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        && (event.modifiers & Qt.ControlModifier) && !inputMethodComposing) {
                    event.accepted = true
                    form.submit()
                }
            }
        }
    }
    RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: 7
        IslandButton {
            text: form.japanese ? "スキップ" : "Skip"
            onClicked: form.hub.send({op:"skip", id:form.request.id, token:form.token})
        }
        IslandButton {
            id: submitButton
            text: form.japanese ? "送信" : "Submit"
            description: text + " (Ctrl+Enter)"
            enabled: (!!form.option || !!editor.text.trim()) && !editor.inputMethodComposing
            background: Rectangle { radius: height / 2; color: submitButton.down ? StyleTokens.textSecondary : StyleTokens.textPrimary }
            contentItem: Text {
                text: submitButton.text; color: StyleTokens.panel
                font.family: UserConfig.textFontFamily; font.weight: Font.DemiBold; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            implicitWidth: Math.max(65, contentItem.implicitWidth + 22)
            onClicked: form.submit()
        }
    }
}
