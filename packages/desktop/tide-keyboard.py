"""Add keyboard navigation and Vimium-style hints to Tide's control center."""

from pathlib import Path
import sys


root = Path(sys.argv[1])
path = root / "qml/controlcenter/ControlCenterLayer.qml"
source = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global source
    if source.count(old) != 1:
        raise RuntimeError(f"upstream ControlCenterLayer changed: {label}")
    source = source.replace(old, new, 1)


replace_once(
    "    property bool powerViewActive: false\n",
    """    property bool powerViewActive: false
    property bool keyboardHintsVisible: false
    property int keyboardSelection: 0
    property string powerConfirmation: ""
    property int powerSelection: 0
    focus: showCondition
    activeFocusOnTab: true
""",
    "keyboard state",
)

replace_once(
    "    function triggerShutdown() {\n",
    """    function keyboardTargets() {
        return [
            { item: dateLabel, hint: "C", action: function() { controlCenter.calendarRequested(); } },
            { item: weatherChip, hint: "E", action: function() { controlCenter.weatherRequested(); } },
            { item: wifiDetailButton, hint: "W", action: function() { controlCenter.toggleConnectivityOverlay("wifi"); } },
            { item: wifiSwitchTrack, hint: "⇧W", action: function() { controlCenter.toggleWifiEnabled(); } },
            { item: bluetoothDetailButton, hint: "B", action: function() { controlCenter.toggleConnectivityOverlay("bluetooth"); } },
            { item: bluetoothSwitchTrack, hint: "⇧B", action: function() { controlCenter.toggleBluetoothEnabled(); } },
            { item: batteryDrawerHandle, hint: "P", action: function() { controlCenter.toggleBatteryDrawer(); } },
            { item: focusButton, hint: "S", action: function() { controlCenter.toggleFocus(); } },
            { item: nightLightButton, hint: "N", action: function() { controlCenter.toggleNightLight(); } },
            { item: brightnessCard, hint: "D", slider: "brightness" },
            { item: volumeCard, hint: "V", slider: "volume" }
        ].filter(function(target) { return target.item && target.item.visible && target.item.enabled; });
    }

    function normalizedKeyboardSelection() {
        const targets = keyboardTargets();
        if (targets.length === 0) return -1;
        keyboardSelection = Math.max(0, Math.min(keyboardSelection, targets.length - 1));
        return keyboardSelection;
    }

    function moveKeyboardSelection(delta) {
        const targets = keyboardTargets();
        if (targets.length === 0) return;
        keyboardSelection = (normalizedKeyboardSelection() + delta + targets.length) % targets.length;
    }

    function activateKeyboardSelection() {
        const targets = keyboardTargets();
        const index = normalizedKeyboardSelection();
        if (index < 0) return;
        const target = targets[index];
        if (target.action) target.action();
    }

    function adjustSelectedSlider(delta) {
        const targets = keyboardTargets();
        const index = normalizedKeyboardSelection();
        if (index < 0 || !targets[index].slider) return false;
        if (targets[index].slider === "brightness") {
            queueBrightness(localBrightness + delta);
            brightnessApplyTimer.stop();
            flushBrightness(true);
        } else {
            queueVolume(localVolume + delta);
            volumeApplyTimer.stop();
            flushVolume(true);
        }
        return true;
    }

    function activateHint(key, modifiers) {
        const shifted = (modifiers & Qt.ShiftModifier) !== 0;
        if (key === Qt.Key_C) { calendarRequested(); return true; }
        if (key === Qt.Key_E) { weatherRequested(); return true; }
        if (key === Qt.Key_W) {
            if (shifted) toggleWifiEnabled(); else toggleConnectivityOverlay("wifi");
            return true;
        }
        if (key === Qt.Key_B) {
            if (shifted) toggleBluetoothEnabled(); else toggleConnectivityOverlay("bluetooth");
            return true;
        }
        if (key === Qt.Key_P) { toggleBatteryDrawer(); return true; }
        if (key === Qt.Key_S) { toggleFocus(); return true; }
        if (key === Qt.Key_N) { toggleNightLight(); return true; }
        if (key === Qt.Key_D || key === Qt.Key_V) {
            const targets = keyboardTargets();
            const wanted = key === Qt.Key_D ? "brightness" : "volume";
            for (let i = 0; i < targets.length; ++i) {
                if (targets[i].slider === wanted) {
                    keyboardSelection = i;
                    return true;
                }
            }
        }
        return false;
    }

    function requestPowerAction(index) {
        powerSelection = index;
        if (index === 0) { triggerLock(); return; }
        if (index === 1) { triggerSleep(); return; }
        powerConfirmation = index === 2 ? "restart" : "shutdown";
    }

    function confirmPowerAction() {
        if (powerConfirmation === "restart") triggerRestart();
        else if (powerConfirmation === "shutdown") triggerShutdown();
        powerConfirmation = "";
    }

    function handleKeyboard(event) {
        if (!showCondition) return;

        if (powerConfirmation !== "") {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                confirmPowerAction();
            else if (event.key === Qt.Key_Escape)
                powerConfirmation = "";
            else
                return;
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_F) {
            keyboardHintsVisible = !keyboardHintsVisible;
            event.accepted = true;
            return;
        }

        if (keyboardHintsVisible) {
            const handled = powerViewActive
                ? ((event.key === Qt.Key_L && (requestPowerAction(0), true))
                    || (event.key === Qt.Key_S && (requestPowerAction(1), true))
                    || (event.key === Qt.Key_R && (requestPowerAction(2), true))
                    || (event.key === Qt.Key_P && (requestPowerAction(3), true)))
                : activateHint(event.key, event.modifiers);
            if (handled) {
                keyboardHintsVisible = false;
                event.accepted = true;
                return;
            }
        }

        if (event.key === Qt.Key_Escape && keyboardHintsVisible) {
            keyboardHintsVisible = false;
            event.accepted = true;
            return;
        }

        const modified = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        const left = event.key === Qt.Key_Left || event.key === (modified ? Qt.Key_@mod:H@ : Qt.Key_@plain:H@);
        const down = event.key === Qt.Key_Down || event.key === (modified ? Qt.Key_@mod:J@ : Qt.Key_@plain:J@);
        const up = event.key === Qt.Key_Up || event.key === (modified ? Qt.Key_@mod:K@ : Qt.Key_@plain:K@);
        const right = event.key === Qt.Key_Right || event.key === (modified ? Qt.Key_@mod:L@ : Qt.Key_@plain:L@);
        if (!powerViewActive && left
                && adjustSelectedSlider((event.modifiers & Qt.ShiftModifier) ? -0.01 : -0.05)) {
            event.accepted = true;
            return;
        }
        if (!powerViewActive && right
                && adjustSelectedSlider((event.modifiers & Qt.ShiftModifier) ? 0.01 : 0.05)) {
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Tab || right || down) {
            const backwards = event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier);
            if (powerViewActive)
                powerSelection = (powerSelection + (backwards ? 3 : 1)) % 4;
            else
                moveKeyboardSelection(backwards ? -1 : 1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Backtab || left || up) {
            if (powerViewActive)
                powerSelection = (powerSelection + 3) % 4;
            else
                moveKeyboardSelection(-1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (powerViewActive) requestPowerAction(powerSelection);
            else activateKeyboardSelection();
            event.accepted = true;
        }
    }

    Keys.onPressed: function(event) { controlCenter.handleKeyboard(event); }

    function triggerShutdown() {
""",
    "keyboard controller",
)

replace_once(
    """    onShowConditionChanged: {
        if (showCondition) {
            syncLevelsFromProps();
""",
    """    onShowConditionChanged: {
        if (showCondition) {
            keyboardHintsVisible = false;
            keyboardSelection = 0;
            powerSelection = 0;
            powerConfirmation = "";
            Qt.callLater(function() { controlCenter.forceActiveFocus(); });
            syncLevelsFromProps();
""",
    "focus on open",
)

replace_once(
    """    Item {
        anchors.fill: parent
        visible: controlCenter.powerViewActive
""",
    """    Rectangle {
        id: keyboardFocusRing
        z: 80
        color: StyleTokens.transparent
        readonly property real focusMargin: 3
        radius: target && target.radius !== undefined && target.radius > 0
            ? target.radius + focusMargin
            : StyleTokens.radiusModule + focusMargin
        border.width: 2
        border.color: StyleTokens.accent
        visible: controlCenter.showCondition && !controlCenter.powerViewActive
            && controlCenter.keyboardTargets().length > 0
        property var target: visible
            ? controlCenter.keyboardTargets()[controlCenter.normalizedKeyboardSelection()].item : null
        x: target ? target.mapToItem(controlCenter, 0, 0).x - focusMargin : 0
        y: target ? target.mapToItem(controlCenter, 0, 0).y - focusMargin : 0
        width: target ? target.width + focusMargin * 2 : 0
        height: target ? target.height + focusMargin * 2 : 0

        Behavior on x { NumberAnimation { duration: 90 } }
        Behavior on y { NumberAnimation { duration: 90 } }
        Behavior on width { NumberAnimation { duration: 90 } }
        Behavior on height { NumberAnimation { duration: 90 } }
    }

    Repeater {
        model: controlCenter.keyboardHintsVisible && !controlCenter.powerViewActive
            ? controlCenter.keyboardTargets() : []
        delegate: Rectangle {
            required property var modelData
            z: 100
            width: hintText.implicitWidth + 10
            height: 20
            radius: 6
            color: StyleTokens.accent
            x: modelData.item.mapToItem(controlCenter, modelData.item.width, 0).x - width / 2
            y: modelData.item.mapToItem(controlCenter, 0, 0).y - height / 2
            border.width: 1
            border.color: StyleTokens.textPrimaryBright

            Text {
                id: hintText
                anchors.centerIn: parent
                text: modelData.hint
                color: StyleTokens.module
                font.family: controlCenter.textFontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
    }

    Item {
        id: powerKeyboardView
        anchors.fill: parent
        visible: controlCenter.powerViewActive
""",
    "focus overlay",
)

replace_once(
    """                delegate: Item {
                    width: 56
                    height: 56

                    Text {
""",
    """                delegate: Item {
                    width: 68
                    height: 78
                    property var powerKeys: ["L", "S", "R", "P"]
                    property var powerLabels: ["Lock", "Sleep", "Restart", "Power off"]

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: 16
                        color: StyleTokens.transparent
                        border.width: controlCenter.powerSelection === index ? 2 : 0
                        border.color: StyleTokens.accent
                    }

                    Text {
""",
    "power focus",
)

replace_once(
    """                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (controlCenter[modelData.action])
                                controlCenter[modelData.action]();
                        }
                    }
""",
    """                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: parent.powerLabels[index]
                        color: StyleTokens.textSecondary
                        font.family: controlCenter.textFontFamily
                        font.pixelSize: 10
                    }

                    Rectangle {
                        visible: controlCenter.keyboardHintsVisible
                        anchors.right: parent.right
                        anchors.top: parent.top
                        width: 22
                        height: 20
                        radius: 6
                        color: StyleTokens.accent
                        border.width: 1
                        border.color: StyleTokens.textPrimaryBright

                        Text {
                            anchors.centerIn: parent
                            text: parent.parent.powerKeys[index]
                            color: StyleTokens.module
                            font.family: controlCenter.textFontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: controlCenter.requestPowerAction(index)
                    }
""",
    "power activation",
)

replace_once(
    """        }
    }
}
""",
    """        }

        Rectangle {
            anchors.centerIn: parent
            z: 120
            visible: controlCenter.powerConfirmation !== ""
            width: 260
            height: 112
            radius: 20
            color: StyleTokens.panel
            border.width: 2
            border.color: StyleTokens.accent

            Column {
                anchors.centerIn: parent
                spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: controlCenter.powerConfirmation === "restart"
                        ? "Restart the computer?" : "Power off the computer?"
                    color: StyleTokens.textPrimaryBright
                    font.family: controlCenter.textFontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Enter to confirm  ·  Esc to cancel"
                    color: StyleTokens.textSecondary
                    font.family: controlCenter.textFontFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}
""",
    "power confirmation",
)

path.write_text(source)

# Keep the slider fill edge and knob center on the same value coordinate. The
# upstream implementation scales one against the full track width and clamps
# the other against the knob bounds, which visibly diverges near either end.
path = root / "qml/controlcenter/ControlSliderCard.qml"
source = path.read_text()

replace_once(
    """            color: "#30000000"
            border.width: 1
""",
    """            color: "#30000000"
            readonly property real knobTravel: Math.max(0, width - root.knobSize)
            readonly property real knobX: root.clamp01(root.value) * knobTravel
            readonly property real knobRightX: knobX + root.knobSize
            border.width: 1
""",
    "slider geometry",
)

replace_once(
    """                width: root.value <= 0.001
                    ? 0
                    : Math.max(34, Math.min(sliderTrack.width, sliderTrack.width * root.value + 1))
""",
    """                // Continue underneath the entire knob. Ending at its
                // center exposes the fill's rounded cap and creates a visible
                // neck immediately before the circular handle.
                width: root.value <= 0.001 ? 0 : sliderTrack.knobRightX
""",
    "slider fill",
)

replace_once(
    """                x: Math.max(0, Math.min(parent.width - width, parent.width * root.value - width / 2))
""",
    """                x: sliderTrack.knobX
""",
    "slider knob",
)

replace_once(
    """                function update(mouseX) {
                    root.valueMoved(root.clamp01(mouseX / width));
                }
""",
    """                function update(mouseX) {
                    if (sliderTrack.knobTravel <= 0) return;
                    root.valueMoved(root.clamp01(
                        (mouseX - root.knobSize / 2) / sliderTrack.knobTravel));
                }
""",
    "slider pointer mapping",
)

path.write_text(source)


# These three views navigate one-dimensional selections. Normalize only their
# selection handlers so text editors and the clipboard history keep native keys.
island = root / "qml/island"
(island / "HorizontalSelection.js").write_text("""function key(event) {
    const modified = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
    const k = event.key;
    if (k === Qt.Key_Up || k === (modified ? Qt.Key_@mod:K@ : Qt.Key_@plain:K@)
            || k === (modified ? Qt.Key_@mod:H@ : Qt.Key_@plain:H@))
        return Qt.Key_Left;
    if (k === Qt.Key_Down || k === (modified ? Qt.Key_@mod:J@ : Qt.Key_@plain:J@)
            || k === (modified ? Qt.Key_@mod:L@ : Qt.Key_@plain:L@))
        return Qt.Key_Right;
    return k;
}
""")

for name in ("WallpaperPickerLayer", "FileShelfLayer", "ClipboardLayer"):
    path = island / (name + ".qml")
    source = 'import "HorizontalSelection.js" as Navigation\n' + path.read_text()
    if name == "ClipboardLayer":
        replace_once(
            "if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {",
            "const key = Navigation.key(event);\n                    if (key === Qt.Key_Right) {",
            "image preview next",
        )
        replace_once("event.key === Qt.Key_Up || event.key === Qt.Key_Left",
                     "key === Qt.Key_Left", "image preview previous")
    else:
        guard = ("if (searchInput.activeFocus && (key === Qt.Key_Left || key === Qt.Key_Right)) return;\n        "
                 if name == "WallpaperPickerLayer" else "")
        replace_once("Keys.onPressed: event => {\n        switch (event.key)",
                     "Keys.onPressed: event => {\n        const key = Navigation.key(event);\n        " + guard + "switch (key)", name)
        replace_once("        case Qt.Key_H:\n", "", name + " left")
        replace_once("        case Qt.Key_L:\n", "", name + " right")
    path.write_text(source)
