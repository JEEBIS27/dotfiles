// Jeebis login view, matching JeebisAstronautLockView.qml.
// SDDM alone owns authentication; no passwords are stored by this theme.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.VirtualKeyboard

Rectangle {
    id: root
    color: "#1a1b26"
    property bool authenticating: false
    property string failureMessage: ""
    property date now: new Date()
    readonly property int fieldWidth: Math.min(384, Math.max(220, width * 0.24))
    FontLoader { source: "Fonts/OpenSans/OpenSans-Regular.ttf" }
    FontLoader { source: "Fonts/OpenSans/OpenSans-Bold.ttf" }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    function submit() {
        if (authenticating || !user.currentText || session.currentIndex < 0) return;
        failureMessage = "";
        authenticating = true;
        var secret = password.text;
        password.clear();
        sddm.login(user.currentText, secret, session.currentIndex);
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.authenticating = false;
            root.failureMessage = "Login failed. Try again.";
            password.forceActiveFocus();
        }
    }
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "Backgrounds/astronaut.png"
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width; sourceSize.height: height
        asynchronous: true
    }
    Item {
        width: Math.min(root.width, Math.max(360, root.width * 0.40))
        height: root.height
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true
        MultiEffect {
            width: root.width; height: root.height
            anchors.centerIn: parent
            source: wallpaper
            blurEnabled: wallpaper.status === Image.Ready
            blur: 0.8; blurMax: 64; autoPaddingEnabled: false
        }
        Rectangle { anchors.fill: parent; color: "#3021222c" }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter; y: root.height * 0.16
        text: Qt.formatDateTime(root.now, "HH:mm")
        color: "white"; font.family: "Open Sans"; font.bold: true
        font.pixelSize: Math.max(48, Math.min(112, root.height * 0.12))
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter; y: root.height * 0.34
        text: Qt.formatDateTime(root.now, "dddd d MMMM")
        color: "white"; font.family: "Open Sans"; font.pixelSize: 22; font.bold: true
    }
    ComboBox {
        id: user
        objectName: "loginUser"
        anchors.horizontalCenter: parent.horizontalCenter; y: root.height * 0.52
        width: root.fieldWidth; height: 30
        model: userModel; textRole: "name"
        currentIndex: Math.max(0, userModel.lastIndex)
        enabled: !root.authenticating
        font.family: "Open Sans"; font.pixelSize: 16
        contentItem: Text {
            text: user.currentText; color: "white"; font: user.font
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        indicator: Item { }
        background: Rectangle { color: user.hovered ? "#3021222c" : "transparent"; radius: 15 }
    }
    TextField {
        id: password
        objectName: "loginPassword"
        anchors.horizontalCenter: parent.horizontalCenter; y: root.height * 0.59
        width: root.fieldWidth; height: 42
        enabled: !root.authenticating
        echoMode: TextInput.Password
        passwordCharacter: "●"
        passwordMaskDelay: 0
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        leftPadding: 18; rightPadding: 18
        color: "white"; font.family: "monospace"; font.pixelSize: 16
        cursorVisible: activeFocus && text.length > 0
        Text {
            anchors.fill: parent
            visible: password.text.length === 0
            text: root.authenticating ? "Checking…" : root.failureMessage || "Enter Password"
            color: root.failureMessage ? "#f7768e" : "#b0b0b0"
            font: password.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle { color: "#78222222"; radius: height / 2 }
        onAccepted: root.submit()
        onTextEdited: root.failureMessage = ""
        Keys.onEscapePressed: clear()
        Keys.onPressed: function(event) {
            if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U) {
                clear(); event.accepted = true;
            }
        }
        Component.onCompleted: forceActiveFocus()
    }
    Button {
        id: login
        anchors.horizontalCenter: parent.horizontalCenter; y: root.height * 0.70
        width: root.fieldWidth; height: 42
        enabled: !root.authenticating
        text: root.authenticating ? "Checking…" : "Login"
        font.pixelSize: 16; font.bold: true
        contentItem: Text { text: login.text; color: "white"; font: login.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { color: login.down ? "#45495d" : "#343746"; radius: height / 2 }
        onClicked: root.submit()
    }
    // Login-only controls, kept outside the shared lock-screen composition.
    ComboBox {
        id: session
        objectName: "loginSession"
        anchors.horizontalCenter: parent.horizontalCenter; y: root.height * 0.82
        width: root.fieldWidth; height: 32
        model: sessionModel; textRole: "name"; currentIndex: Math.max(0, sessionModel.lastIndex)
        enabled: !root.authenticating
        palette.buttonText: "white"; font.pixelSize: 13
        contentItem: Text {
            text: session.currentText; color: "white"; font: session.font
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle { color: "#78222222"; radius: 16 }
    }
    component ActionButton: Button {
        id: action
        height: 32
        font.pixelSize: 13
        contentItem: Text {
            text: action.text; color: "white"; font: action.font
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle { color: action.down ? "#45495d" : "#343746"; radius: height / 2 }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter; y: root.height * 0.90
        spacing: 12
        ActionButton { text: "Keyboard"; onClicked: { password.forceActiveFocus(); Qt.inputMethod.show(); } }
        ActionButton { text: "Suspend"; visible: sddm.canSuspend; onClicked: sddm.suspend() }
        ActionButton { text: "Restart"; visible: sddm.canReboot; onClicked: sddm.reboot() }
        ActionButton { text: "Shut down"; visible: sddm.canPowerOff; onClicked: sddm.powerOff() }
    }
    InputPanel {
        z: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width, 900)
        y: active ? root.height - height : root.height
    }
}
