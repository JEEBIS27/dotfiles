import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Effects
import TideIsland 1.0

PagePanel {
    id: root
    objectName: "lockScreenSettings"
    property var values: backend.lockScreenSettings()

    function update(key, value) {
        const next = Object.assign({}, values);
        next[key] = value;
        values = next;
        ConfigStore.setLockValue(key, value);
        saveTimer.restart();
    }
    function flush() {
        if (saveTimer.running) {
            saveTimer.stop();
            ConfigStore.save();
        }
    }
    function savePosition(key, x, y) {
        const positions = Object.assign({}, values.positions);
        positions[key] = {
            x: x,
            y: y
        };
        update("positions", positions);
    }
    function saveCoordinate(key, axis, value) {
        const point = preview.widgetPosition(key);
        const coordinate = Math.max(0, Math.min(100, value)) / 100;
        savePosition(key, axis === "x" ? coordinate : point.x, axis === "y" ? coordinate : point.y);
    }
    function resetPosition(key) {
        const positions = Object.assign({}, values.positions);
        delete positions[key];
        update("positions", positions);
    }
    onVisibleChanged: if (!visible)
        flush()
    Component.onDestruction: flush()
    Timer {
        id: saveTimer
        interval: 200
        onTriggered: ConfigStore.save()
    }
    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: preview.now = new Date()
    }
    LockScreenTransition {
        id: previewTransition
        active: root.visible && !root.values.customLayoutEnabled
        onExitFinished: enter()
    }

    FileDialog {
        id: imageDialog
        property string settingKey: "wallpaperPath"
        title: settingKey === "avatarPath" ? "アバター画像を選択" : "ロック画面の壁紙を選択"
        acceptLabel: "選択"
        rejectLabel: "キャンセル"
        nameFilters: ["画像 (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: root.update(settingKey, selectedFile.toString())
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight + 100
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        interactive: false

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: function (event) {
                const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 80;
                const maxY = Math.max(0, scroller.contentHeight - scroller.height);
                scroller.contentY = Math.max(0, Math.min(maxY, scroller.contentY - rawDelta));
                event.accepted = true;
            }
        }

        Column {
            id: content
            x: 30
            y: 50
            width: scroller.width - 70
            spacing: 34

            Item {
                width: parent.width
                height: pageTitle.implicitHeight
                Text {
                    id: pageTitle
                    x: 30
                    text: "ロック画面"
                    color: Theme.textColor
                    font.family: Theme.titleFontFamily
                    font.pixelSize: 30
                }
                SettingButton {
                    anchors.right: parent.right
                    width: 114
                    anchors.verticalCenter: parent.verticalCenter
                    text: "今すぐロック"
                    primary: true
                    font.family: Theme.textFontFamily
                    onClicked: {
                        root.flush();
                        backend.lockScreen();
                    }
                }
            }

            Section {
                title: "配置"
                width: parent.width
                ToggleRow {
                    title: "カードの位置を変更"
                    hint: "プレビューでカードをドラッグするか、下で座標を入力します。変更は自動保存されます。"
                    settingKey: "customLayoutEnabled"
                }

                SplitLine {
                    width: parent.width
                }

                Rectangle {
                    id: previewFrame
                    width: parent.width
                    height: width * 0.59
                    radius: 12
                    color: Theme.componentBgColor
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: previewMask
                    }
                    Rectangle {
                        id: previewMask
                        anchors.fill: parent
                        radius: 12
                        visible: false
                        layer.enabled: true
                    }
                    // The exact production view, scaled down. All example data is preview-only.
                    LockScreenView {
                        id: preview
                        objectName: "lockScreenPreview"
                        width: 1440
                        height: 850
                        scale: parent.width / 1440
                        transformOrigin: Item.TopLeft
                        settings: root.values
                        styleTokens: StyleTokens
                        preview: true
                        interactive: false
                        layoutEditing: root.values.customLayoutEnabled
                        editingUiScale: width / previewFrame.width / Math.max(0.1, sceneScale)
                        entrance: layoutEditing ? 1 : previewTransition.entrance
                        departure: layoutEditing ? 0 : previewTransition.departure
                        unlocking: !layoutEditing && previewTransition.exiting
                        onPositionEdited: (key, x, y) => root.savePosition(key, x, y)
                        userName: "ユーザー名"
                        wallpaperPath: backend.themeLockWallpaper
                        textFont: String(ConfigStore.value("textFontFamily", "Sans Serif"))
                        timeFont: String(ConfigStore.value("timeFontFamily", "Sans Serif"))
                        trackTitle: "Midnight City"
                        trackArtist: "M83"
                        playing: true
                        canPlay: true
                        canPrevious: true
                        canNext: true
                        canFavorite: true
                        favorite: true
                        favoriteHint: "お気に入り（Spotify接続時に利用可能）"
                        progress: 0.38
                        elapsed: "1:24"
                        duration: "3:42"
                        weatherReady: true
                        temperature: "23°"
                        weatherCondition: "晴れ時々曇り"
                        weatherLocation: "現在地の天気"
                        weatherType: "cloudy"
                        feelsLike: "24°"
                        humidity: "64%"
                        hasBattery: true
                        batteryPercent: 86
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(49, previewHint.implicitHeight, previewActions.implicitHeight)

                    Text {
                        id: previewHint
                        anchors.left: parent.left
                        anchors.right: previewActions.left
                        anchors.rightMargin: 28
                        anchors.verticalCenter: parent.verticalCenter
                        text: "音楽と天気はサンプルです。"
                        wrapMode: Text.Wrap
                        color: Theme.subtleTextColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                    }

                    Row {
                        id: previewActions
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        SettingButton {
                            text: "位置をリセット"
                            enabled: Object.keys(root.values.positions).length > 0
                            onClicked: root.update("positions", {})
                        }
                        SettingButton {
                            text: "動きを再生"
                            enabled: !root.values.customLayoutEnabled && !previewTransition.exiting
                            onClicked: previewTransition.beginExit()
                        }
                    }
                }
            }

            Section {
                title: "カードの位置"
                width: parent.width
                visible: root.values.customLayoutEnabled

                Text {
                    width: parent.width
                    text: "XとYは画面に対するカード中心の位置（%）です。カードは画面内に収まります。"
                    wrapMode: Text.Wrap
                    color: Theme.subtleTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                }

                Repeater {
                    model: [
                        {key: "profile", label: "ユーザー情報"},
                        {key: "clock", label: "時刻と日付"},
                        {key: "password", label: "パスワード"},
                        {key: "weather", label: "天気"},
                        {key: "music", label: "音楽プレーヤー"}
                    ]

                    PositionRow {
                        required property var modelData
                        title: modelData.label
                        widgetKey: modelData.key
                    }
                }
            }

            Section {
                title: "外観"
                width: parent.width

                SettingRow {
                    title: "壁紙"
                    hint: root.values.wallpaperPath || "現在のデスクトップテーマのロック画面用壁紙を使う"
                    elideHint: true
                    SettingButton {
                        text: "画像を選択"
                        onClicked: {
                            imageDialog.settingKey = "wallpaperPath";
                            imageDialog.open();
                        }
                    }
                    SettingButton {
                        text: "リセット"
                        enabled: root.values.wallpaperPath !== ""
                        onClicked: root.update("wallpaperPath", "")
                    }
                }

                SplitLine {
                    width: parent.width
                }

                NumberRow {
                    title: "背景のぼかし"
                    hint: "ロック画面の壁紙のぼかし（0〜100%）"
                    settingKey: "blur"
                }

                SplitLine {
                    width: parent.width
                }

                NumberRow {
                    title: "背景の暗さ"
                    hint: "カードの背後の壁紙を暗くする度合い（0〜100%）"
                    settingKey: "dim"
                }

                SplitLine {
                    width: parent.width
                }

                NumberRow {
                    title: "カードの不透明度"
                    hint: "ロック画面のカード背景の濃さ（0〜100%）"
                    settingKey: "cardOpacity"
                }

                SplitLine {
                    width: parent.width
                }

                NumberRow {
                    title: "角の丸み"
                    hint: "ロック画面のカードの角丸半径（12〜40 px）"
                    settingKey: "radius"
                    minimum: 12
                    maximum: 40
                }
            }

            Section {
                title: "ユーザー情報"
                width: parent.width
                ToggleRow {
                    title: "アバター"
                    hint: "ロック画面にプロフィール画像を表示"
                    settingKey: "showAvatar"
                }

                SplitLine {
                    width: parent.width
                    visible: root.values.showAvatar
                }

                SettingRow {
                    title: "アバター画像"
                    hint: root.values.avatarPath || "システムのプロフィール画像を使う"
                    elideHint: true
                    visible: root.values.showAvatar
                    SettingButton {
                        text: "アバターを選択"
                        onClicked: {
                            imageDialog.settingKey = "avatarPath";
                            imageDialog.open();
                        }
                    }
                    SettingButton {
                        text: "リセット"
                        enabled: root.values.avatarPath !== ""
                        onClicked: root.update("avatarPath", "")
                    }
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "名前を表示"
                    hint: "ロック画面にユーザー名を表示"
                    settingKey: "showName"
                }

                SplitLine {
                    width: parent.width
                    visible: root.values.showName
                }

                TextRow {
                    title: "表示名"
                    hint: "空欄の場合はシステムのユーザー名を使います。"
                    settingKey: "displayName"
                    placeholderText: "システムのユーザー名"
                    maximumLength: 80
                    visible: root.values.showName
                }

                SplitLine {
                    width: parent.width
                }

                TextRow {
                    title: "ロック画面のメッセージ"
                    hint: "時計の下に短いメッセージを表示"
                    settingKey: "message"
                    placeholderText: "空欄で非表示"
                    maximumLength: 180
                }
            }

            Section {
                title: "時刻と日付"
                width: parent.width
                ToggleRow {
                    title: "時計"
                    hint: "ロック画面に現在の時刻を表示"
                    settingKey: "showClock"
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "日付と曜日"
                    hint: "現在の日付と曜日を表示"
                    settingKey: "showDate"
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "24時間表示"
                    hint: "時刻を24時間形式で表示"
                    settingKey: "use24Hour"
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "秒を表示"
                    hint: "時計に秒を表示"
                    settingKey: "showSeconds"
                }
            }

            Section {
                title: "ウィジェット"
                width: parent.width
                ToggleRow {
                    title: "音楽プレーヤー"
                    hint: "Islandのプレーヤーを操作するボタンを表示"
                    settingKey: "showMusic"
                }

                SplitLine {
                    width: parent.width
                    visible: root.values.showMusic
                }

                ToggleRow {
                    title: "曲名とアーティスト"
                    hint: "再生中の曲名とアーティスト名を表示"
                    settingKey: "showTrackInfo"
                    visible: root.values.showMusic
                }

                SplitLine {
                    width: parent.width
                    visible: root.values.showMusic
                }

                ToggleRow {
                    title: "アルバムアート"
                    hint: "再生中の曲のアルバムアートを表示"
                    settingKey: "showAlbumArt"
                    visible: root.values.showMusic
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "現在の天気"
                    hint: "「外観 → 天気」で選んだ地域と単位を使用"
                    settingKey: "showWeather"
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "バッテリーと充電"
                    hint: "ユーザー情報カードにバッテリー残量と充電状態を表示"
                    settingKey: "showBattery"
                }
            }

            Text {
                width: parent.width
                text: "電源メニューまたはSuper+Escで画面をロックできます。"
                wrapMode: Text.Wrap
                color: Theme.secondaryTextColor
                font.family: Theme.textFontFamily
                font.pixelSize: 12
                lineHeight: 1.4
            }
        }
    }

    component SettingButton: Button {
        id: button
        property bool primary: false
        implicitWidth: label.implicitWidth + 28
        implicitHeight: 36
        padding: 0
        hoverEnabled: true
        opacity: enabled ? 1 : 0.45

        HoverHandler {
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        contentItem: Text {
            id: label
            text: button.text
            color: button.primary ? Theme.buttonTextColor : Theme.mutedButtonTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 6
            color: button.primary ? (button.down ? Theme.buttonPressedColor : button.hovered ? Theme.buttonHoverColor : Theme.buttonColor) : (button.down ? Theme.controlPressedColor : button.hovered ? Theme.mutedButtonHoverColor : Theme.mutedButtonColor)
            border.width: 1
            border.color: button.visualFocus ? Theme.focusBorderColor : button.primary ? color : Theme.inputBorderColor

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animationDuration
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.animationDuration
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                border.width: 3
                border.color: Theme.focusRingColor
                opacity: button.visualFocus ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationDuration
                    }
                }
            }
        }
    }

    component SplitLine: Rectangle {
        height: 1
        color: Theme.splitLineColor
    }

    component Section: Item {
        id: section
        property string title
        default property alias contents: sectionBody.data
        implicitHeight: sectionTitle.implicitHeight + 15 + sectionPanel.height
        Text {
            id: sectionTitle
            x: 2
            text: section.title
            color: Theme.textColor
            font.family: Theme.titleFontFamily
            font.pixelSize: 23
        }
        Rectangle {
            id: sectionPanel
            y: sectionTitle.implicitHeight + 15
            width: parent.width
            height: sectionBody.implicitHeight + 36
            color: Theme.cardBgColor
            radius: 16
            border.width: 1
            border.color: Theme.splitLineColor
            Column {
                id: sectionBody
                x: 18
                y: 18
                width: parent.width - 36
                spacing: 16
            }
        }
    }

    component SettingRow: Item {
        id: row
        property string title
        property string hint: ""
        property bool elideHint: false
        default property alias controls: rowControls.data
        width: parent.width
        height: Math.max(49, rowLabels.implicitHeight, rowControls.implicitHeight)

        Column {
            id: rowLabels
            anchors.left: parent.left
            anchors.right: rowControls.left
            anchors.rightMargin: 28
            anchors.top: parent.top
            spacing: 5
            Text {
                width: parent.width
                text: row.title
                wrapMode: Text.Wrap
                color: Theme.textColor
                font.family: Theme.textFontFamily
                font.pixelSize: 18
            }
            Text {
                width: parent.width
                visible: row.hint !== ""
                text: row.hint
                wrapMode: row.elideHint ? Text.NoWrap : Text.Wrap
                elide: row.elideHint ? Text.ElideMiddle : Text.ElideNone
                color: Theme.subtleTextColor
                font.family: Theme.textFontFamily
                font.pixelSize: 14
            }
        }

        Row {
            id: rowControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }

    component ToggleRow: SettingRow {
        id: toggle
        property string settingKey

        Switch {
            id: toggleControl
            checked: root.values[toggle.settingKey]
            Accessible.name: toggle.title
            onToggled: root.update(toggle.settingKey, checked)
            implicitWidth: 48
            implicitHeight: 26
            padding: 0

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            indicator: Rectangle {
                width: 40
                height: 24
                radius: 12
                anchors.centerIn: parent
                color: toggleControl.checked ? Theme.accentColor : Theme.componentBgColor
                border.width: toggleControl.visualFocus ? 2 : 1
                border.color: toggleControl.visualFocus ? Theme.focusBorderColor : toggleControl.checked ? Theme.accentColor : Theme.inputBorderColor

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animationDuration
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.animationDuration
                    }
                }

                Rectangle {
                    x: toggleControl.checked ? 19 : 3
                    y: 3
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.cardBgColor
                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
            contentItem: Item {}
        }
    }

    component PositionRow: SettingRow {
        id: positionRow
        required property string widgetKey
        readonly property point currentPosition: preview.widgetPosition(widgetKey)

        Text {
            text: "X"
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.subtleTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }
        CoordinateField {
            objectName: positionRow.widgetKey + "PositionX"
            currentValue: positionRow.currentPosition.x * 100
            field.Accessible.name: positionRow.title + "の横位置（%）"
            onCommitted: value => root.saveCoordinate(positionRow.widgetKey, "x", value)
        }
        Text {
            text: "Y"
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.subtleTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }
        CoordinateField {
            objectName: positionRow.widgetKey + "PositionY"
            currentValue: positionRow.currentPosition.y * 100
            field.Accessible.name: positionRow.title + "の縦位置（%）"
            onCommitted: value => root.saveCoordinate(positionRow.widgetKey, "y", value)
        }
        SettingButton {
            objectName: positionRow.widgetKey + "PositionReset"
            text: "リセット"
            Accessible.name: positionRow.title + "の位置をリセット"
            enabled: root.values.positions[positionRow.widgetKey] !== undefined
            onClicked: root.resetPosition(positionRow.widgetKey)
        }
    }

    component CoordinateField: ConfigTextField {
        id: coordinateField
        required property real currentValue
        signal committed(real value)
        width: 82
        height: 36
        text: currentValue.toFixed(1)
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        validator: DoubleValidator {
            bottom: 0
            top: 100
            decimals: 1
            notation: DoubleValidator.StandardNotation
            locale: "C"
        }
        onAccepted: commit()
        onEditingFinished: commit()
        onCurrentValueChanged: if (!field.activeFocus)
            text = currentValue.toFixed(1)

        function commit() {
            const value = Number(text);
            if (text.trim() !== "" && isFinite(value))
                committed(Math.max(0, Math.min(100, value)));
            text = currentValue.toFixed(1);
        }
    }

    component TextRow: SettingRow {
        id: textRow
        property string settingKey
        property string placeholderText: ""
        property int maximumLength: 180

        ConfigTextField {
            width: 230
            height: 36
            text: root.values[textRow.settingKey]
            placeholderText: textRow.placeholderText
            field.maximumLength: textRow.maximumLength
            field.Accessible.name: textRow.title
            onAccepted: commit()
            onEditingFinished: commit()

            function commit() {
                root.update(textRow.settingKey, text.trim());
            }
        }
    }

    component NumberRow: SettingRow {
        id: numberRow
        property string settingKey
        property int minimum: 0
        property int maximum: 100

        IntValidator {
            id: numberValidator
            bottom: numberRow.minimum
            top: numberRow.maximum
        }

        ConfigTextField {
            width: 100
            height: 36
            text: String(root.values[numberRow.settingKey])
            inputMethodHints: Qt.ImhDigitsOnly
            validator: numberValidator
            field.Accessible.name: numberRow.title
            onAccepted: commit()
            onEditingFinished: commit()

            function commit() {
                const parsed = Number(text);
                if (text.trim() !== "" && isFinite(parsed)) {
                    root.update(numberRow.settingKey, Math.max(numberRow.minimum, Math.min(numberRow.maximum, Math.round(parsed))));
                }
                text = String(root.values[numberRow.settingKey]);
            }
        }
    }
}
