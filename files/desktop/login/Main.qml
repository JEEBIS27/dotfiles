// Tide's display-only view; SDDM owns login and session creation.
import QtQuick
import QtQuick.Controls
import QtQuick.VirtualKeyboard
import "TideLock"
import "Palette.js" as Palette

Rectangle {
    id: root
    color: "#202125"
    property bool authenticating: false
    property string failureMessage: ""
    property date now: new Date()
    property var themeTokens: Palette.tokens
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    function submit(secret: string) {
        if (authenticating || !user.currentText || session.currentIndex < 0) return;
        failureMessage = "";
        authenticating = true;
        lockView.clearInput();
        sddm.login(user.currentText, secret, session.currentIndex);
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.authenticating = false;
            root.failureMessage = "Login failed. Try again.";
            lockView.focusInput();
        }
    }
    LockScreenView {
        id: lockView
        objectName: "tideLoginView"
        anchors.fill: parent
        userName: user.currentText
        now: root.now
        wallpaperPath: "/var/lib/jeebis-theme/current/lock-wallpaper"
        styleTokens: root.themeTokens
        busy: root.authenticating
        authError: root.failureMessage.length > 0
        authMessage: root.failureMessage
        prompt: "Password"
        // Session data is unavailable before login. Keep the shared clock,
        // profile and password cards, without placeholder media/weather data.
        settings: ({showMusic: false, showWeather: false, showBattery: false})
        onSubmitted: response => root.submit(response)
        onCancelAuthentication: root.failureMessage = ""
    }
    component Picker: ComboBox {
        id: picker
        width: 210
        height: 36
        enabled: !root.authenticating
        palette.buttonText: "#f5f5f7"
        palette.text: "#f5f5f7"
        palette.base: "#202125"
        font.pixelSize: 13
        contentItem: Text {
            text: picker.currentText; color: "#f5f5f7"; font: picker.font
            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
            leftPadding: 16; rightPadding: 28
        }
        background: Rectangle { color: "#d1202125"; radius: 18; border.color: "#26ffffff" }
    }
    component ActionButton: Button {
        id: action
        width: 210; height: 36
        font.pixelSize: 13
        contentItem: Text {
            text: action.text; color: "#f5f5f7"; font: action.font
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: action.down ? "#303136" : "#d1202125"
            radius: 18; border.color: action.activeFocus ? "#89b4fa" : "#26ffffff"
        }
    }
    Flow {
        id: controls
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: Math.min(660, root.width - 32)
        spacing: 8
        Picker {
            id: user
            objectName: "loginUser"
            model: userModel; textRole: "name"
            currentIndex: Math.max(0, userModel.lastIndex)
            Accessible.name: "User"
            onActivated: { lockView.clearInput(); root.failureMessage = ""; }
        }
        Picker {
            id: session
            objectName: "loginSession"
            model: sessionModel; textRole: "name"
            currentIndex: Math.max(0, sessionModel.lastIndex)
            Accessible.name: "Session"
        }
        ActionButton {
            text: "Keyboard"
            onClicked: { lockView.focusInput(); Qt.inputMethod.show(); }
        }
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
